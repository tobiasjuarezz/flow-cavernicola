-- =====================================================================
--  FLOW CAVERNÍCOLA — Estructura de la base de datos (SaaS Parte 5)
--  Motor: PostgreSQL (Supabase)
--
--  Cómo usarlo: en Supabase entrar a SQL Editor > New query, pegar
--  todo este archivo y darle a Run. Después correr seed.sql.
--
--  Se puede correr más de una vez: al principio borra todo y lo
--  vuelve a crear desde cero (OJO: también borra los datos).
-- =====================================================================


-- ---------------------------------------------------------------------
-- 0. Limpieza (para poder reconstruir la estructura desde cero)
-- ---------------------------------------------------------------------
drop trigger  if exists al_registrarse_usuario on auth.users;
drop function if exists public.crear_barberia_al_registrarse() cascade;
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
--    Cuando alguien se registra en la app (registro.vue manda el nombre
--    de la barbería en user_metadata.barberia), se crea sola su
--    barbería y su perfil con rol "dueno".
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

  return new;
end;
$$;

create trigger al_registrarse_usuario
  after insert on auth.users
  for each row execute function public.crear_barberia_al_registrarse();
