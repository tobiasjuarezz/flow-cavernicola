-- =====================================================================
--  FLOW CAVERNÍCOLA — Datos de prueba (SaaS Parte 5)
--  Correr DESPUÉS de schema.sql (SQL Editor > New query > Run).
--
--  Carga 2 barberías con sus barberos, servicios, horarios, clientes
--  y turnos, para comprobar que cada dato queda asociado a la suya.
--
--  Usuarios de prueba (todos con contraseña 123456):
--    tano@lacueva.com     -> dueño de La Cueva Barber
--    rulo@lacueva.com     -> barbero de La Cueva Barber
--    nico@eltano.com      -> dueño de Barbería El Tano
-- =====================================================================

-- Limpio los datos de prueba anteriores (si ya se había corrido)
delete from auth.users
where id in ('a0000000-0000-4000-8000-000000000001',
             'a0000000-0000-4000-8000-000000000002',
             'a0000000-0000-4000-8000-000000000003');

delete from public.barberias
where id in ('b0000000-0000-4000-8000-000000000001',
             'b0000000-0000-4000-8000-000000000002');


-- ---------------------------------------------------------------------
-- 1. Usuarios en Supabase Auth (las contraseñas van encriptadas ahí,
--    nunca en nuestras tablas). No mando "barberia" en los metadatos
--    para que el trigger no cree barberías automáticas.
-- ---------------------------------------------------------------------
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
)
values
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000001',
   'authenticated', 'authenticated', 'tano@lacueva.com', crypt('123456', gen_salt('bf')),
   now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Gastón \"Tano\" Ríos"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000002',
   'authenticated', 'authenticated', 'rulo@lacueva.com', crypt('123456', gen_salt('bf')),
   now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Rodrigo \"Rulo\" Paz"}',
   now(), now(), '', '', '', ''),
  ('00000000-0000-0000-0000-000000000000', 'a0000000-0000-4000-8000-000000000003',
   'authenticated', 'authenticated', 'nico@eltano.com', crypt('123456', gen_salt('bf')),
   now(), '{"provider":"email","providers":["email"]}', '{"nombre":"Nicolás Ferreyra"}',
   now(), now(), '', '', '', '');

-- Supabase también necesita la "identidad" de email para poder loguearse
insert into auth.identities (
  id, user_id, provider_id, provider, identity_data,
  last_sign_in_at, created_at, updated_at
)
select gen_random_uuid(), u.id, u.id::text, 'email',
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
from auth.users u
where u.id in ('a0000000-0000-4000-8000-000000000001',
               'a0000000-0000-4000-8000-000000000002',
               'a0000000-0000-4000-8000-000000000003');


-- ---------------------------------------------------------------------
-- 2. Barberías (las 2 organizaciones)
-- ---------------------------------------------------------------------
insert into public.barberias (id, nombre, slug, telefono, direccion, plan)
values
  ('b0000000-0000-4000-8000-000000000001', 'La Cueva Barber', 'la-cueva-barber',
   '11 5555-1010', 'Av. Alem 345, Monte Grande', 'profesional'),
  ('b0000000-0000-4000-8000-000000000002', 'Barbería El Tano', 'barberia-el-tano',
   '11 5555-2020', 'Boedo 120, Lomas de Zamora', 'gratis');


-- ---------------------------------------------------------------------
-- 3. Perfiles (barberos) — cada uno atado a su usuario y su barbería
-- ---------------------------------------------------------------------
insert into public.perfiles (id, barberia_id, nombre, telefono, rol)
values
  ('a0000000-0000-4000-8000-000000000001', 'b0000000-0000-4000-8000-000000000001',
   'Gastón "Tano" Ríos', '11 6000-0001', 'dueno'),
  ('a0000000-0000-4000-8000-000000000002', 'b0000000-0000-4000-8000-000000000001',
   'Rodrigo "Rulo" Paz', '11 6000-0002', 'barbero'),
  ('a0000000-0000-4000-8000-000000000003', 'b0000000-0000-4000-8000-000000000002',
   'Nicolás Ferreyra', '11 6000-0003', 'dueno');


-- ---------------------------------------------------------------------
-- 4. Servicios (los ids los genera la base, así que después los busco
--    por nombre + barbería)
-- ---------------------------------------------------------------------
insert into public.servicios (barberia_id, nombre, duracion_min, precio)
values
  ('b0000000-0000-4000-8000-000000000001', 'Corte clásico',  30, 9000),
  ('b0000000-0000-4000-8000-000000000001', 'Corte + barba',  45, 13000),
  ('b0000000-0000-4000-8000-000000000001', 'Corte + diseño', 45, 12000),
  ('b0000000-0000-4000-8000-000000000001', 'Barba',          20, 6000),
  ('b0000000-0000-4000-8000-000000000002', 'Corte clásico',  30, 7500),
  ('b0000000-0000-4000-8000-000000000002', 'Corte niño',     30, 6000),
  ('b0000000-0000-4000-8000-000000000002', 'Afeitado',       25, 5000);


-- ---------------------------------------------------------------------
-- 5. Horarios de atención (1 = lunes ... 6 = sábado)
-- ---------------------------------------------------------------------
insert into public.horarios (barberia_id, perfil_id, dia_semana, hora_inicio, hora_fin)
select 'b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000001',
       d, '10:00', '20:00'
from generate_series(2, 6) d;                       -- Tano: martes a sábado

insert into public.horarios (barberia_id, perfil_id, dia_semana, hora_inicio, hora_fin)
select 'b0000000-0000-4000-8000-000000000001', 'a0000000-0000-4000-8000-000000000002',
       d, '14:00', '21:00'
from generate_series(1, 5) d;                       -- Rulo: lunes a viernes, tarde

insert into public.horarios (barberia_id, perfil_id, dia_semana, hora_inicio, hora_fin)
values
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 1, '09:00', '13:00'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 1, '16:00', '20:00'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 3, '09:00', '13:00'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 3, '16:00', '20:00'),
  ('b0000000-0000-4000-8000-000000000002', 'a0000000-0000-4000-8000-000000000003', 5, '09:00', '20:00');


-- ---------------------------------------------------------------------
-- 6. Clientes. Ojo: Facundo tiene el MISMO teléfono en las dos
--    barberías, y son dos registros distintos (cada barbería tiene
--    su propia lista de clientes).
-- ---------------------------------------------------------------------
insert into public.clientes (barberia_id, nombre, telefono)
values
  ('b0000000-0000-4000-8000-000000000001', 'Facundo Medina',  '11 4444-1111'),
  ('b0000000-0000-4000-8000-000000000001', 'Lucas Romero',    '11 4444-2222'),
  ('b0000000-0000-4000-8000-000000000001', 'Matías Gómez',    '11 4444-3333'),
  ('b0000000-0000-4000-8000-000000000002', 'Facundo Medina',  '11 4444-1111'),
  ('b0000000-0000-4000-8000-000000000002', 'Julián Sosa',     '11 4444-5555');


-- ---------------------------------------------------------------------
-- 7. Turnos. Busco los ids de cliente y servicio por subconsulta.
-- ---------------------------------------------------------------------
insert into public.turnos (barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora, estado)
select
  t.barberia_id::uuid,
  (select id from public.clientes  c where c.barberia_id = t.barberia_id::uuid and c.telefono = t.telefono),
  (select id from public.servicios s where s.barberia_id = t.barberia_id::uuid and s.nombre   = t.servicio),
  t.perfil_id::uuid,
  current_date + t.dias,
  t.hora::time,
  t.estado
from (values
  -- La Cueva Barber
  ('b0000000-0000-4000-8000-000000000001', '11 4444-1111', 'Corte + barba',  'a0000000-0000-4000-8000-000000000001', 0, '10:00', 'completado'),
  ('b0000000-0000-4000-8000-000000000001', '11 4444-2222', 'Corte clásico',  'a0000000-0000-4000-8000-000000000001', 0, '11:00', 'confirmado'),
  ('b0000000-0000-4000-8000-000000000001', '11 4444-3333', 'Corte + diseño', 'a0000000-0000-4000-8000-000000000002', 0, '15:00', 'pendiente'),
  ('b0000000-0000-4000-8000-000000000001', '11 4444-2222', 'Barba',          'a0000000-0000-4000-8000-000000000002', 1, '16:30', 'pendiente'),
  ('b0000000-0000-4000-8000-000000000001', '11 4444-1111', 'Corte clásico',  'a0000000-0000-4000-8000-000000000001', 1, '12:00', 'cancelado'),
  -- Barbería El Tano
  ('b0000000-0000-4000-8000-000000000002', '11 4444-1111', 'Corte clásico',  'a0000000-0000-4000-8000-000000000003', 0, '09:30', 'confirmado'),
  ('b0000000-0000-4000-8000-000000000002', '11 4444-5555', 'Corte niño',     'a0000000-0000-4000-8000-000000000003', 0, '17:00', 'pendiente'),
  ('b0000000-0000-4000-8000-000000000002', '11 4444-5555', 'Afeitado',       'a0000000-0000-4000-8000-000000000003', 2, '10:00', 'pendiente')
) as t(barberia_id, telefono, servicio, perfil_id, dias, hora, estado);


-- =====================================================================
-- 8. CONSULTAS DE COMPROBACIÓN (correrlas aparte para ver resultados)
-- =====================================================================

-- a) Cuántos registros tiene cada barbería
-- select b.nombre,
--        (select count(*) from perfiles  p where p.barberia_id = b.id) as barberos,
--        (select count(*) from servicios s where s.barberia_id = b.id) as servicios,
--        (select count(*) from clientes  c where c.barberia_id = b.id) as clientes,
--        (select count(*) from turnos    t where t.barberia_id = b.id) as turnos
-- from barberias b order by b.nombre;

-- b) Agenda completa con todos los datos unidos
-- select b.nombre as barberia, t.fecha, t.hora, c.nombre as cliente,
--        s.nombre as servicio, s.precio, p.nombre as barbero, t.estado
-- from turnos t
-- join barberias b on b.id = t.barberia_id
-- join clientes  c on c.id = t.cliente_id
-- join servicios s on s.id = t.servicio_id
-- join perfiles  p on p.id = t.perfil_id
-- order by b.nombre, t.fecha, t.hora;

-- c) Esto TIENE QUE FALLAR: turno de La Cueva con un servicio de El Tano
-- insert into turnos (barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora)
-- values ('b0000000-0000-4000-8000-000000000001',
--         (select id from clientes  where barberia_id = 'b0000000-0000-4000-8000-000000000001' limit 1),
--         (select id from servicios where barberia_id = 'b0000000-0000-4000-8000-000000000002' limit 1),
--         'a0000000-0000-4000-8000-000000000001', current_date, '19:00');
