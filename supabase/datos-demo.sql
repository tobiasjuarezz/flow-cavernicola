-- =====================================================================
--  FLOW CAVERNÍCOLA — Datos para la demostración (Parte Final)
--
--  Para qué: los turnos de seed.sql se cargaron con fechas relativas
--  al día en que se corrió (octubre), así que hoy la agenda aparece
--  vacía. Este script carga turnos FICTICIOS para HOY y los próximos
--  6 días, así la demo muestra un recorrido completo.
--
--  Cómo: SQL Editor > New query > pegar todo > Run.
--  Correrlo el mismo día de la presentación (las fechas salen de
--  current_date). Se puede correr varias veces: no repite turnos.
--  No borra nada.
--
--  Reglas que respeta (igual que una reserva real):
--    - Solo carga un turno si el barbero trabaja ese día y a esa hora
--      (tabla horarios) y el servicio entra antes de que cierre.
--    - No pisa turnos que ya existan (mismo barbero, día y hora).
--    - Los turnos de hoy cuya hora ya pasó quedan como "completado".
--    - Todo con datos inventados: nombres y teléfonos ficticios.
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1. Más clientes ficticios (si ya existen, no hace nada)
-- ---------------------------------------------------------------------
insert into public.clientes (barberia_id, nombre, telefono)
values
  -- La Cueva Barber
  ('b0000000-0000-4000-8000-000000000001', 'Tomás Herrera',    '11 4444-6001'),
  ('b0000000-0000-4000-8000-000000000001', 'Bruno Castillo',   '11 4444-6002'),
  ('b0000000-0000-4000-8000-000000000001', 'Agustín Molina',   '11 4444-6003'),
  ('b0000000-0000-4000-8000-000000000001', 'Franco Ledesma',   '11 4444-6004'),
  ('b0000000-0000-4000-8000-000000000001', 'Santino Vera',     '11 4444-6005'),
  ('b0000000-0000-4000-8000-000000000001', 'Joaquín Benítez',  '11 4444-6006'),
  -- Barbería El Tano
  ('b0000000-0000-4000-8000-000000000002', 'Ezequiel Ruiz',    '11 4444-7001'),
  ('b0000000-0000-4000-8000-000000000002', 'Gonzalo Acosta',   '11 4444-7002'),
  ('b0000000-0000-4000-8000-000000000002', 'Ramiro Ponce',     '11 4444-7003')
on conflict (barberia_id, telefono) do nothing;


-- ---------------------------------------------------------------------
-- 2. Turnos para hoy y los próximos 6 días
--
--    "plantilla" es un día tipo: qué barbero, a qué hora, qué servicio
--    y en qué estado. Se repite para cada uno de los 7 días, y después
--    se descartan los que caen fuera del horario del barbero (por
--    ejemplo, Tano no trabaja los lunes y Rulo solo trabaja de tarde).
--
--    "giro" sirve para ir rotando los clientes: así no aparece
--    siempre el mismo cliente a la misma hora.
-- ---------------------------------------------------------------------
with plantilla (barberia_id, perfil_id, hora, servicio, estado, giro) as (
  values
    -- La Cueva Barber · Tano (dueño): martes a sábado, 10 a 20
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '10:00', 'Corte clásico',  'confirmado', 0),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '11:30', 'Corte + barba',  'pendiente',  1),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '13:00', 'Barba',          'confirmado', 2),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '17:00', 'Corte + diseño', 'pendiente',  3),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001', '18:30', 'Corte clásico',  'cancelado',  4),
    -- La Cueva Barber · Rulo (barbero): lunes a viernes, 14 a 21
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '14:00', 'Corte clásico',  'confirmado', 5),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '16:00', 'Corte + barba',  'pendiente',  6),
    ('b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002', '19:30', 'Corte + diseño', 'pendiente',  7),
    -- Barbería El Tano · Nico (dueño): lun y mié 9-13 y 16-20, vie 9-20
    ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', '09:30', 'Corte clásico',  'confirmado', 0),
    ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', '11:00', 'Corte niño',     'pendiente',  1),
    ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', '17:30', 'Afeitado',       'pendiente',  2)
),

dias as (
  select generate_series(0, 6) as n          -- hoy (0) ... dentro de 6 días
),

candidatos as (
  select
    p.barberia_id::uuid    as barberia_id,
    p.perfil_id::uuid      as perfil_id,
    current_date + d.n     as fecha,
    p.hora::time           as hora,
    p.servicio,
    p.estado,
    p.giro + d.n           as giro
  from plantilla p
  cross join dias d
),

-- Numero los clientes de cada barbería (0, 1, 2...) para rotarlos
clientes_numerados as (
  select
    id,
    barberia_id,
    row_number() over (partition by barberia_id order by id) - 1 as nro,
    count(*)     over (partition by barberia_id)                 as total
  from public.clientes
  where barberia_id in ('b0000000-0000-4000-8000-000000000001',
                        'b0000000-0000-4000-8000-000000000002')
)

insert into public.turnos (barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora, estado)
select
  c.barberia_id,
  cl.id,
  s.id,
  c.perfil_id,
  c.fecha,
  c.hora,
  -- si el turno es de hoy y la hora ya pasó, lo muestro como atendido
  case
    when c.estado <> 'cancelado'
     and (c.fecha + c.hora) < (now() at time zone 'America/Argentina/Buenos_Aires')
    then 'completado'
    else c.estado
  end
from candidatos c
-- el servicio tiene que existir y estar activo en esa barbería
join public.servicios s
  on s.barberia_id = c.barberia_id
 and s.nombre      = c.servicio
 and s.activo
-- el barbero tiene que trabajar ese día, y el servicio tiene que
-- terminar antes de que cierre. Uso extract(dow) igual que la función
-- horarios_disponibles: 0 = domingo, 1 = lunes ... 6 = sábado
join public.horarios h
  on h.perfil_id   = c.perfil_id
 and h.dia_semana  = extract(dow from c.fecha)
 and c.hora       >= h.hora_inicio
 and c.hora + make_interval(mins => s.duracion_min) <= h.hora_fin
-- el cliente que le toca según el giro
join clientes_numerados cl
  on cl.barberia_id = c.barberia_id
 and cl.nro         = c.giro % cl.total
-- no repetir: si ese barbero ya tiene un turno ese día a esa hora
-- (aunque esté cancelado), no cargo otro
where not exists (
  select 1
  from public.turnos t
  where t.perfil_id = c.perfil_id
    and t.fecha     = c.fecha
    and t.hora      = c.hora
)
on conflict do nothing;


-- ---------------------------------------------------------------------
-- 3. Comprobación: cuántos turnos quedaron por barbería y por día
--    (correr aparte si querés ver el resultado)
-- ---------------------------------------------------------------------
-- select b.nombre as barberia, t.fecha, count(*) as turnos
-- from public.turnos t
-- join public.barberias b on b.id = t.barberia_id
-- where t.fecha between current_date and current_date + 6
-- group by b.nombre, t.fecha
-- order by b.nombre, t.fecha;
