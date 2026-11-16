-- =====================================================================
--  FLOW CAVERNÍCOLA — Actualización Parte Final
--
--  Para qué: si tu base ya tiene schema.sql, actualizacion.sql y
--  actualizacion-parte7.sql corridos, corré SOLO este archivo
--  (SQL Editor > New query > pegar > Run). No borra datos.
--
--  Si arrancás una base desde cero NO hace falta: schema.sql ya trae
--  todo esto. Se puede correr más de una vez sin romper nada.
--
--  Qué agrega:
--    1. Los horarios de un barbero no se pueden superponer el mismo
--       día (antes solo lo controlaba la pantalla).
--    2. Arreglo de seguridad que encontré en las pruebas: el dueño
--       podía cambiarse el PLAN de su barbería llamando a la API
--       directo (por ejemplo de "gratis" a "empresa", sin pagar).
--       Ahora desde la app solo se pueden modificar el nombre, el
--       teléfono y la dirección. El plan y el link (slug) quedan fijos.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Horarios sin superponerse
--    Dos franjas se pisan si una empieza antes de que termine la otra.
--    Ej: martes 10:00-14:00 y martes 13:00-18:00 -> se pisan.
--        martes 10:00-14:00 y martes 16:00-20:00 -> no (horario cortado).
-- ---------------------------------------------------------------------
create or replace function public.horarios_sin_superponer()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if exists (
    select 1
    from public.horarios h
    where h.perfil_id   = new.perfil_id
      and h.dia_semana  = new.dia_semana
      and h.id is distinct from new.id        -- al editar, no me comparo conmigo
      and new.hora_inicio < h.hora_fin
      and h.hora_inicio   < new.hora_fin
  ) then
    -- 23P01 = "exclusion_violation": la pantalla lo traduce a un mensaje
    raise exception 'La franja se superpone con otra del mismo barbero ese día'
      using errcode = '23P01';
  end if;
  return new;
end;
$$;

drop trigger if exists horarios_sin_superponer on public.horarios;
create trigger horarios_sin_superponer
  before insert or update on public.horarios
  for each row execute function public.horarios_sin_superponer();


-- ---------------------------------------------------------------------
-- 2. Qué columnas de la barbería se pueden modificar desde la app
--    RLS decide QUÉ FILAS puede tocar cada uno (solo el dueño, solo la
--    suya). Los permisos por columna deciden QUÉ DATOS de esa fila.
--    Saco el permiso de modificar la tabla entera y lo doy solo para
--    nombre, teléfono y dirección.
-- ---------------------------------------------------------------------
revoke update on public.barberias from anon, authenticated;
grant update (nombre, telefono, direccion) on public.barberias to authenticated;
