-- =====================================================================
--  FLOW CAVERNÍCOLA — Estructura de la base de datos
--  Motor: PostgreSQL (Supabase)
--
--  Cómo usarlo: en Supabase entrar a SQL Editor > New query, pegar
--  todo este archivo y darle a Run. Después correr seed.sql.
--
--  Se puede correr más de una vez: al principio borra todo y lo
--  vuelve a crear desde cero (OJO: también borra los datos).
--
--  Si ya tenías la base creada y NO querés perder los datos, no
--  corras este archivo: corré actualizacion.sql, que agrega solo
--  lo nuevo (reservas públicas y datos iniciales).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Limpieza (para poder reconstruir la estructura desde cero)
-- ---------------------------------------------------------------------
drop trigger  if exists al_registrarse_usuario on auth.users;
drop function if exists public.crear_barberia_al_registrarse() cascade;
drop function if exists public.cargar_datos_iniciales(uuid, uuid) cascade;
drop function if exists public.horarios_disponibles(text, date) cascade;
drop function if exists public.reservar_turno(text, bigint, date, time, text, text) cascade;
drop function if exists public.mi_barberia() cascade;
drop function if exists public.generar_slug(text) cascade;

drop table if exists public.turnos    cascade;
drop table if exists public.clientes  cascade;
drop table if exists public.horarios  cascade;
drop table if exists public.servicios cascade;
drop table if exists public.perfiles  cascade;
drop table if exists public.barberias cascade;


-- ---------------------------------------------------------------------
-- 1. BARBERIAS — cada negocio que usa la plataforma (la "organización")
-- ---------------------------------------------------------------------
create table public.barberias (
  id          uuid        primary key default gen_random_uuid(),
  nombre      text        not null check (length(trim(nombre)) > 0),
  slug        text        not null unique
                          check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  telefono    text,
  direccion   text,
  plan        text        not null default 'gratis'
                          check (plan in ('gratis', 'basico', 'profesional', 'empresa')),
  created_at  timestamptz not null default now()
);


-- ---------------------------------------------------------------------
-- 2. PERFILES — datos de los barberos que inician sesión.
--    El id ES el mismo id del usuario de Supabase Auth (auth.users).
--    Acá NO se guarda la contraseña: de eso se encarga Supabase Auth.
-- ---------------------------------------------------------------------
create table public.perfiles (
  id           uuid        primary key references auth.users (id) on delete cascade,
  barberia_id  uuid        not null references public.barberias (id) on delete cascade,
  nombre       text        not null check (length(trim(nombre)) > 0),
  telefono     text,
  rol          text        not null default 'barbero'
                           check (rol in ('dueno', 'barbero')),
  activo       boolean     not null default true,
  created_at   timestamptz not null default now(),

  -- Lo necesito para que otras tablas puedan exigir
  -- "este barbero pertenece a ESTA barbería" (ver turnos y horarios)
  unique (id, barberia_id)
);

-- Una barbería puede tener un solo dueño
create unique index un_dueno_por_barberia
  on public.perfiles (barberia_id)
  where rol = 'dueno';


-- ---------------------------------------------------------------------
-- 3. SERVICIOS — lo que ofrece cada barbería (corte, barba, etc.)
-- ---------------------------------------------------------------------
create table public.servicios (
  id            bigint        generated always as identity primary key,
  barberia_id   uuid          not null references public.barberias (id) on delete cascade,
  nombre        text          not null check (length(trim(nombre)) > 0),
  duracion_min  integer       not null check (duracion_min > 0),
  precio        numeric(10,2) not null check (precio >= 0),
  activo        boolean       not null default true,

  unique (barberia_id, nombre),   -- no repetir el mismo servicio en una barbería
  unique (id, barberia_id)
);


-- ---------------------------------------------------------------------
-- 4. HORARIOS — en qué días y horas atiende cada barbero
--    dia_semana: 0 = domingo, 1 = lunes, ..., 6 = sábado
-- ---------------------------------------------------------------------
create table public.horarios (
  id           bigint   generated always as identity primary key,
  barberia_id  uuid     not null,
  perfil_id    uuid     not null,
  dia_semana   smallint not null check (dia_semana between 0 and 6),
  hora_inicio  time     not null,
  hora_fin     time     not null,

  check (hora_fin > hora_inicio),

  -- el barbero tiene que ser de la misma barbería
  foreign key (perfil_id, barberia_id)
    references public.perfiles (id, barberia_id) on delete cascade,
  foreign key (barberia_id)
    references public.barberias (id) on delete cascade
);


-- ---------------------------------------------------------------------
-- 5. CLIENTES — la gente que reserva. NO tienen cuenta ni contraseña:
--    solo nombre y WhatsApp. Cada barbería tiene sus propios clientes.
-- ---------------------------------------------------------------------
create table public.clientes (
  id           bigint      generated always as identity primary key,
  barberia_id  uuid        not null references public.barberias (id) on delete cascade,
  nombre       text        not null check (length(trim(nombre)) > 0),
  telefono     text        not null check (length(trim(telefono)) > 0),
  created_at   timestamptz not null default now(),

  -- el mismo número puede ser cliente de dos barberías distintas,
  -- pero dentro de una barbería no se repite
  unique (barberia_id, telefono),
  unique (id, barberia_id)
);


-- ---------------------------------------------------------------------
-- 6. TURNOS — la tabla central: une barbería, cliente, servicio y barbero
-- ---------------------------------------------------------------------
create table public.turnos (
  id                    bigint      generated always as identity primary key,
  barberia_id           uuid        not null references public.barberias (id) on delete cascade,
  cliente_id            bigint      not null,
  servicio_id           bigint      not null,
  perfil_id             uuid        not null,
  fecha                 date        not null,
  hora                  time        not null,
  estado                text        not null default 'pendiente'
                                    check (estado in ('pendiente', 'confirmado', 'completado', 'cancelado')),
  recordatorio_enviado  boolean     not null default false,
  notas                 text,
  created_at            timestamptz not null default now(),

  -- Claves foráneas compuestas: obligan a que el cliente, el servicio
  -- y el barbero sean TODOS de la misma barbería que el turno.
  foreign key (cliente_id, barberia_id)
    references public.clientes (id, barberia_id) on delete cascade,
  foreign key (servicio_id, barberia_id)
    references public.servicios (id, barberia_id),   -- no deja borrar un servicio que tiene turnos
  foreign key (perfil_id, barberia_id)
    references public.perfiles (id, barberia_id) on delete cascade
);

-- Un barbero no puede tener dos turnos a la misma hora el mismo día
-- (los cancelados no cuentan, así ese horario se puede volver a usar)
create unique index turnos_sin_pisar
  on public.turnos (perfil_id, fecha, hora)
  where estado <> 'cancelado';

-- Índices para que la agenda cargue rápido (se filtra por barbería + fecha)
create index turnos_por_barberia_fecha on public.turnos (barberia_id, fecha);
create index turnos_por_cliente        on public.turnos (cliente_id);
create index horarios_por_perfil       on public.horarios (perfil_id);


-- =====================================================================
-- 7. SEGURIDAD (Row Level Security)
--    Cada barbero solo puede ver y tocar los datos de SU barbería.
-- =====================================================================

-- Devuelve la barbería del usuario logueado.
-- "security definer" = corre con permisos del dueño de la función,
-- así puede leer perfiles sin chocar con sus propias políticas.
create function public.mi_barberia()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select barberia_id from public.perfiles where id = auth.uid()
$$;

alter table public.barberias enable row level security;
alter table public.perfiles  enable row level security;
alter table public.servicios enable row level security;
alter table public.horarios  enable row level security;
alter table public.clientes  enable row level security;
alter table public.turnos    enable row level security;

-- BARBERIAS: cualquiera puede leerlas (la página pública de reserva
-- busca la barbería por su slug). Solo el dueño puede editar la suya.
create policy "barberias: lectura publica"
  on public.barberias for select
  using (true);

create policy "barberias: el dueno edita la suya"
  on public.barberias for update to authenticated
  using (
    id = public.mi_barberia()
    and exists (select 1 from public.perfiles
                where id = auth.uid() and rol = 'dueno')
  );

-- PERFILES: veo a los barberos de mi barbería; cada uno edita el suyo
create policy "perfiles: ver los de mi barberia"
  on public.perfiles for select to authenticated
  using (barberia_id = public.mi_barberia());

create policy "perfiles: editar el propio"
  on public.perfiles for update to authenticated
  using (id = auth.uid())
  with check (barberia_id = public.mi_barberia());

-- SERVICIOS y HORARIOS: lectura pública (para reservar) y
-- edición solo desde la barbería dueña
create policy "servicios: lectura publica de los activos"
  on public.servicios for select
  using (activo or barberia_id = public.mi_barberia());

create policy "servicios: gestion de mi barberia"
  on public.servicios for all to authenticated
  using (barberia_id = public.mi_barberia())
  with check (barberia_id = public.mi_barberia());

create policy "horarios: lectura publica"
  on public.horarios for select
  using (true);

create policy "horarios: gestion de mi barberia"
  on public.horarios for all to authenticated
  using (barberia_id = public.mi_barberia())
  with check (barberia_id = public.mi_barberia());

-- CLIENTES y TURNOS: son datos privados de cada barbería
create policy "clientes: solo mi barberia"
  on public.clientes for all to authenticated
  using (barberia_id = public.mi_barberia())
  with check (barberia_id = public.mi_barberia());

create policy "turnos: solo mi barberia"
  on public.turnos for all to authenticated
  using (barberia_id = public.mi_barberia())
  with check (barberia_id = public.mi_barberia());


-- =====================================================================
-- 8. REGISTRO AUTOMÁTICO
--    Cuando alguien se registra en la app (RegistroView.vue manda el
--    nombre de la barbería en user_metadata.barberia), se crea sola su
--    barbería, su perfil con rol "dueno" y unos datos iniciales para
--    que pueda recibir reservas desde el primer minuto.
-- =====================================================================

-- "Barbería El Tano" -> "barberia-el-tano"
create function public.generar_slug(texto text)
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
create function public.cargar_datos_iniciales(p_barberia uuid, p_perfil uuid)
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

create function public.crear_barberia_al_registrarse()
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

create trigger al_registrarse_usuario
  after insert on auth.users
  for each row execute function public.crear_barberia_al_registrarse();


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
create function public.horarios_disponibles(p_slug text, p_fecha date)
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
create function public.reservar_turno(
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
