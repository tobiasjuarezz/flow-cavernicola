-- =====================================================================
--  FLOW CAVERNÍCOLA — Actualización Parte 7: permisos por rol
--
--  Para qué: si tu base ya tiene schema.sql (y actualizacion.sql)
--  corridos, corré SOLO este archivo (SQL Editor > New query > pegar
--  > Run). No borra datos: cambia las reglas de seguridad (RLS) para
--  que cada usuario pueda hacer solo lo que le permite su rol.
--
--  Si arrancás una base desde cero NO hace falta: schema.sql ya trae
--  todo esto. Se puede correr más de una vez sin romper nada.
--
--    | Acción                          | dueno | barbero         |
--    |---------------------------------|-------|-----------------|
--    | Ver turnos y clientes           |  sí   | sí              |
--    | Crear / modificar turnos        |  sí   | solo los suyos  |
--    | Eliminar turnos y clientes      |  sí   | no              |
--    | Crear / editar / borrar servic. |  sí   | no (solo ver)   |
--    | Cambiar horarios                |  sí   | no (solo ver)   |
--    | Editar los datos de la barbería |  sí   | no              |
--    | Cambiar su propio rol           |  no   | no              |
-- =====================================================================

-- Saco las reglas viejas (las de la Parte 5), que no distinguían roles
drop policy if exists "barberias: el dueno edita la suya" on public.barberias;
drop policy if exists "perfiles: editar el propio" on public.perfiles;
drop policy if exists "servicios: gestion de mi barberia" on public.servicios;
drop policy if exists "horarios: gestion de mi barberia" on public.horarios;
drop policy if exists "clientes: solo mi barberia" on public.clientes;
drop policy if exists "turnos: solo mi barberia" on public.turnos;

-- Devuelve el rol del usuario logueado ('dueno' o 'barbero').
-- Si el perfil está desactivado devuelve null: pierde los permisos.
create or replace function public.mi_rol()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select rol from public.perfiles where id = auth.uid() and activo
$$;

alter table public.barberias enable row level security;
alter table public.perfiles  enable row level security;
alter table public.servicios enable row level security;
alter table public.horarios  enable row level security;
alter table public.clientes  enable row level security;
alter table public.turnos    enable row level security;

-- BARBERIAS: cualquiera puede leerlas (la página pública de reserva
-- busca la barbería por su slug). Solo el dueño puede editar la suya.
drop policy if exists "barberias: lectura publica" on public.barberias;
create policy "barberias: lectura publica"
  on public.barberias for select
  using (true);

drop policy if exists "barberias: el dueno edita la suya" on public.barberias;
create policy "barberias: el dueno edita la suya"
  on public.barberias for update to authenticated
  using (id = public.mi_barberia() and public.mi_rol() = 'dueno')
  with check (id = public.mi_barberia());

-- PERFILES: veo a los barberos de mi barbería; cada uno edita el suyo,
-- pero NO puede cambiarse el rol ni pasarse a otra barbería
-- (mi_rol() todavía ve el rol de antes del cambio).
drop policy if exists "perfiles: ver los de mi barberia" on public.perfiles;
create policy "perfiles: ver los de mi barberia"
  on public.perfiles for select to authenticated
  using (barberia_id = public.mi_barberia());

drop policy if exists "perfiles: editar el propio sin cambiar el rol" on public.perfiles;
create policy "perfiles: editar el propio sin cambiar el rol"
  on public.perfiles for update to authenticated
  using (id = auth.uid())
  with check (barberia_id = public.mi_barberia() and rol = public.mi_rol());

-- SERVICIOS y HORARIOS: lectura pública (para reservar).
-- Crear, modificar y eliminar: solo el dueño de la barbería.
drop policy if exists "servicios: lectura publica de los activos" on public.servicios;
create policy "servicios: lectura publica de los activos"
  on public.servicios for select
  using (activo or barberia_id = public.mi_barberia());

drop policy if exists "servicios: el dueno los gestiona" on public.servicios;
create policy "servicios: el dueno los gestiona"
  on public.servicios for all to authenticated
  using (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno')
  with check (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno');

drop policy if exists "horarios: lectura publica" on public.horarios;
create policy "horarios: lectura publica"
  on public.horarios for select
  using (true);

drop policy if exists "horarios: el dueno los gestiona" on public.horarios;
create policy "horarios: el dueno los gestiona"
  on public.horarios for all to authenticated
  using (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno')
  with check (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno');

-- CLIENTES: todos los de la barbería los ven, cargan y corrigen;
-- eliminar, solo el dueño.
drop policy if exists "clientes: ver los de mi barberia" on public.clientes;
create policy "clientes: ver los de mi barberia"
  on public.clientes for select to authenticated
  using (barberia_id = public.mi_barberia());

drop policy if exists "clientes: cargar en mi barberia" on public.clientes;
create policy "clientes: cargar en mi barberia"
  on public.clientes for insert to authenticated
  with check (barberia_id = public.mi_barberia());

drop policy if exists "clientes: editar los de mi barberia" on public.clientes;
create policy "clientes: editar los de mi barberia"
  on public.clientes for update to authenticated
  using (barberia_id = public.mi_barberia())
  with check (barberia_id = public.mi_barberia());

drop policy if exists "clientes: solo el dueno elimina" on public.clientes;
create policy "clientes: solo el dueno elimina"
  on public.clientes for delete to authenticated
  using (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno');

-- TURNOS: todos los de la barbería ven la agenda completa.
-- El dueño crea y modifica cualquiera; el barbero, solo los suyos.
-- Eliminar, solo el dueño (el barbero puede cancelarlos).
drop policy if exists "turnos: ver los de mi barberia" on public.turnos;
create policy "turnos: ver los de mi barberia"
  on public.turnos for select to authenticated
  using (barberia_id = public.mi_barberia());

drop policy if exists "turnos: crear (el barbero solo para si mismo)" on public.turnos;
create policy "turnos: crear (el barbero solo para si mismo)"
  on public.turnos for insert to authenticated
  with check (
    barberia_id = public.mi_barberia()
    and (public.mi_rol() = 'dueno' or perfil_id = auth.uid())
  );

drop policy if exists "turnos: modificar (el barbero solo los suyos)" on public.turnos;
create policy "turnos: modificar (el barbero solo los suyos)"
  on public.turnos for update to authenticated
  using (
    barberia_id = public.mi_barberia()
    and (public.mi_rol() = 'dueno' or perfil_id = auth.uid())
  )
  with check (
    barberia_id = public.mi_barberia()
    and (public.mi_rol() = 'dueno' or perfil_id = auth.uid())
  );

drop policy if exists "turnos: solo el dueno elimina" on public.turnos;
create policy "turnos: solo el dueno elimina"
  on public.turnos for delete to authenticated
  using (barberia_id = public.mi_barberia() and public.mi_rol() = 'dueno');
