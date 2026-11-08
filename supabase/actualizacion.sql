-- =====================================================================
--  FLOW CAVERNÍCOLA — Actualización de una base que YA existe
--
--  Para qué: si ya corriste schema.sql y seed.sql antes, corré SOLO
--  este archivo (SQL Editor > New query > pegar > Run). No borra
--  nada: agrega lo nuevo y deja tus datos como están.
--
--  Qué agrega:
--    1. Datos iniciales (servicios + horarios) para cada barbería
--       nueva que se registra.
--    2. Las funciones de reserva pública que usa la página
--       /reservar/:slug (el cliente reserva sin cuenta).
--    3. Le carga servicios y horarios a las barberías que ya se
--       registraron y no tenían ninguno.
--
--  Si arrancás una base desde cero NO hace falta: schema.sql ya
--  trae todo esto. Se puede correr más de una vez sin romper nada.
-- =====================================================================

-- =====================================================================
-- 8. REGISTRO AUTOMÁTICO
--    Cuando alguien se registra en la app (RegistroView.vue manda el
--    nombre de la barbería en user_metadata.barberia), se crea sola su
--    barbería, su perfil con rol "dueno" y unos datos iniciales para
--    que pueda recibir reservas desde el primer minuto.
-- =====================================================================

-- "Barbería El Tano" -> "barberia-el-tano"
create or replace function public.generar_slug(texto text)
returns text
language sql
immutable
as $$
  select trim(both '-' from
           regexp_replace(
             lower(translate(texto, 'áéíóúüñÁÉÍÓÚÜÑ', 'aeiouunaeiouun')),
             '[^a-z0-9]+', '-', 'g'))
$$;

-- Servicios y horarios de arranque para una barbería nueva.
-- Sin esto, una barbería recién registrada no tiene servicios ni
-- horarios, y entonces nadie puede reservarle un turno.
-- Horario inicial: lunes a sábado de 10 a 20 hs.
create or replace function public.cargar_datos_iniciales(p_barberia uuid, p_perfil uuid)
returns void
language sql
as $$
  insert into public.servicios (barberia_id, nombre, duracion_min, precio)
  values (p_barberia, 'Corte clásico', 30, 9000),
         (p_barberia, 'Corte + barba', 45, 13000),
         (p_barberia, 'Barba',         20, 6000)
  on conflict (barberia_id, nombre) do nothing;

  insert into public.horarios (barberia_id, perfil_id, dia_semana, hora_inicio, hora_fin)
  select p_barberia, p_perfil, d, '10:00', '20:00'
  from generate_series(1, 6) as d
  where not exists (select 1 from public.horarios where perfil_id = p_perfil);
$$;

create or replace function public.crear_barberia_al_registrarse()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  nombre_barberia text := trim(new.raw_user_meta_data ->> 'barberia');
  slug_base       text;
  slug_final      text;
  nueva_id        uuid;
begin
  -- Si no vino nombre de barbería (ej: usuarios cargados a mano), no hago nada
  if nombre_barberia is null or nombre_barberia = '' then
    return new;
  end if;

  slug_base := coalesce(nullif(public.generar_slug(nombre_barberia), ''), 'barberia');
  slug_final := slug_base;

  -- Si el slug ya existe le agrego un sufijo: la-cueva-2, la-cueva-3...
  while exists (select 1 from public.barberias where slug = slug_final) loop
    slug_final := slug_base || '-' || floor(random() * 9000 + 1000)::int;
  end loop;

  insert into public.barberias (nombre, slug)
  values (nombre_barberia, slug_final)
  returning id into nueva_id;

  insert into public.perfiles (id, barberia_id, nombre, rol)
  values (
    new.id,
    nueva_id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'nombre'), ''), split_part(new.email, '@', 1)),
    'dueno'
  );

  perform public.cargar_datos_iniciales(nueva_id, new.id);

  return new;
end;
$$;



-- =====================================================================
-- 9. RESERVAS PÚBLICAS (el cliente reserva SIN cuenta)
--
--    Problema: las políticas de clientes y turnos son solo para
--    usuarios logueados, así que un cliente anónimo no puede ni ver
--    qué horarios están ocupados ni insertar su turno.
--
--    Solución: dos funciones "security definer". Corren con permisos
--    del dueño de la base, pero solo hacen UNA cosa controlada:
--      - horarios_disponibles: devuelve las horas libres, sin datos
--        de otros clientes.
--      - reservar_turno: valida todo y recién ahí inserta.
--    Desde Vue se llaman con supabase.rpc("nombre_funcion", {...}).
-- =====================================================================

-- Horas libres de una barbería en una fecha, de a 30 minutos.
-- Una hora está libre si AL MENOS UN barbero trabaja a esa hora y no
-- tiene otro turno (los cancelados no cuentan).
create or replace function public.horarios_disponibles(p_slug text, p_fecha date)
returns table (hora time)
language sql
stable
security definer
set search_path = public
as $$
  select distinct franja.hora
  from public.barberias b
  join public.horarios  h on h.barberia_id = b.id
  join public.perfiles  p on p.id = h.perfil_id and p.activo
  cross join lateral (
    select g::time as hora
    from generate_series(p_fecha + h.hora_inicio,
                         p_fecha + h.hora_fin - interval '30 minutes',
                         interval '30 minutes') as g
  ) as franja
  where b.slug = p_slug
    and h.dia_semana = extract(dow from p_fecha)
    -- no ofrezco horas que ya pasaron (la base está en UTC, paso a hora argentina)
    and p_fecha + franja.hora > now() at time zone 'America/Argentina/Buenos_Aires'
    and not exists (
      select 1 from public.turnos t
      where t.perfil_id = h.perfil_id
        and t.fecha     = p_fecha
        and t.hora      = franja.hora
        and t.estado   <> 'cancelado'
    )
  order by franja.hora
$$;

-- Crea la reserva. Devuelve los datos para la pantalla de confirmación.
create or replace function public.reservar_turno(
  p_slug        text,
  p_servicio_id bigint,
  p_fecha       date,
  p_hora        time,
  p_nombre      text,
  p_telefono    text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_barberia  public.barberias%rowtype;
  v_servicio  text;
  v_perfil    uuid;
  v_cliente   bigint;
  v_turno     bigint;
begin
  if coalesce(trim(p_nombre), '') = '' or coalesce(trim(p_telefono), '') = '' then
    raise exception 'Completá tu nombre y tu teléfono.';
  end if;

  select * into v_barberia from public.barberias where slug = p_slug;
  if not found then
    raise exception 'Esa barbería no existe.';
  end if;

  -- El servicio tiene que ser de ESTA barbería y estar activo
  select nombre into v_servicio
  from public.servicios
  where id = p_servicio_id and barberia_id = v_barberia.id and activo;
  if not found then
    raise exception 'Ese servicio no está disponible.';
  end if;

  if p_fecha + p_hora <= now() at time zone 'America/Argentina/Buenos_Aires' then
    raise exception 'Ese horario ya pasó.';
  end if;

  -- Busco un barbero que trabaje a esa hora y esté libre.
  -- Si hay varios, le doy el turno al que tiene menos turnos ese día.
  select h.perfil_id into v_perfil
  from public.horarios h
  join public.perfiles p on p.id = h.perfil_id and p.activo
  where h.barberia_id = v_barberia.id
    and h.dia_semana  = extract(dow from p_fecha)
    and p_hora >= h.hora_inicio
    and p_hora <  h.hora_fin
    and not exists (
      select 1 from public.turnos t
      where t.perfil_id = h.perfil_id
        and t.fecha     = p_fecha
        and t.hora      = p_hora
        and t.estado   <> 'cancelado'
    )
  order by (select count(*) from public.turnos t2
            where t2.perfil_id = h.perfil_id
              and t2.fecha     = p_fecha
              and t2.estado   <> 'cancelado')
  limit 1;

  if v_perfil is null then
    raise exception 'Ese horario ya no está disponible.';
  end if;

  -- Si el teléfono ya es cliente de esta barbería, uso ese registro
  -- (y NO le piso el nombre: un anónimo no tiene que poder cambiarlo)
  insert into public.clientes (barberia_id, nombre, telefono)
  values (v_barberia.id, trim(p_nombre), trim(p_telefono))
  on conflict (barberia_id, telefono) do update set nombre = clientes.nombre
  returning id into v_cliente;

  -- Si dos personas reservan la misma hora al mismo tiempo, el índice
  -- "turnos_sin_pisar" frena al segundo con el error 23505
  insert into public.turnos (barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora)
  values (v_barberia.id, v_cliente, p_servicio_id, v_perfil, p_fecha, p_hora)
  returning id into v_turno;

  return jsonb_build_object(
    'turno_id', v_turno,
    'barberia', v_barberia.nombre,
    'servicio', v_servicio,
    'fecha',    p_fecha,
    'hora',     to_char(p_hora, 'HH24:MI')
  );
end;
$$;

-- Quién puede llamar a cada función desde la app
grant execute on function public.horarios_disponibles(text, date) to anon, authenticated;
grant execute on function public.reservar_turno(text, bigint, date, time, text, text) to anon, authenticated;

-- Esta la usa solo el trigger: nadie la tiene que poder llamar con rpc()
revoke execute on function public.cargar_datos_iniciales(uuid, uuid) from public, anon, authenticated;


-- =====================================================================
-- 10. Barberías que ya existían sin servicios: les cargo los de arranque
--     (las del seed ya tienen los suyos, así que no se tocan)
-- =====================================================================
select public.cargar_datos_iniciales(p.barberia_id, p.id)
from public.perfiles p
where p.rol = 'dueno'
  and not exists (select 1 from public.servicios s where s.barberia_id = p.barberia_id);
