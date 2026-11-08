# Flow Cavernícola ✂️

**Turnos sin vueltas.** Agenda de turnos online para barberías chicas.

Cada barbería tiene su propio link de reserva (por ejemplo `/reservar/la-cueva-barber`). El cliente entra, elige servicio, día y hora, y reserva **sin crearse una cuenta**. El barbero ve todo ordenado en su agenda.

Proyecto de la materia PDISC 7.6 — E.E.S. Técnica N°1, Esteban Echeverría.

## Qué hace

**Dueño de la barbería (con cuenta)**
- Se registra con el nombre de su barbería. La base le crea sola la barbería, su link y unos servicios y horarios de arranque.
- Ve la agenda de toda la barbería: por día, los próximos 7 días o todos, con búsqueda por cliente o teléfono, filtro por estado y orden.
- Crea, edita, cancela y elimina cualquier turno (pide confirmación antes de eliminar).
- Administra los servicios: alta, edición de precio y duración, activar/desactivar y baja.
- Copia o abre su link de reservas para compartirlo.

**Barbero empleado (con cuenta)**
- Ve la agenda de la barbería, pero solo crea y modifica **sus** turnos.
- No elimina turnos (los cancela) y no puede tocar los servicios.

**Cliente (sin cuenta)**
- Entra por el link de la barbería.
- Elige servicio, día y una hora libre (las ocupadas y las que ya pasaron no aparecen).
- Deja nombre y WhatsApp, y listo.

## Tecnologías

- **Vue 3** (JavaScript) + **Vue Router** + **Vite**
- **Supabase**: PostgreSQL, Auth y Row Level Security

## Cómo correrlo

```bash
npm install
npm run dev
```

Sin configurar nada arranca en **modo demo**: el login y los datos se guardan en el navegador (localStorage). Sirve para probar la app sin base de datos.

### Con Supabase

1. Crear un proyecto en [supabase.com](https://supabase.com).
2. En **SQL Editor**, correr `supabase/schema.sql` y después `supabase/seed.sql`.
3. En **Authentication > Providers > Email**, desactivar *Confirm email* (para probar más rápido).
4. Copiar `.env.example` como `.env` y completar la URL y la anon key (**Project Settings > API**).
5. `npm run dev`

**¿Ya tenías la base creada?** No vuelvas a correr `schema.sql` (borra todo). Corré en orden las actualizaciones que te falten, que no tocan tus datos:
- `supabase/actualizacion.sql` (Parte 6: reservas públicas)
- `supabase/actualizacion-parte7.sql` (Parte 7: permisos por rol)

### Usuarios de prueba (del seed)

| Email | Contraseña | Barbería | Link de reservas |
|---|---|---|---|
| tano@lacueva.com | 123456 | La Cueva Barber (**dueño**) | `/reservar/la-cueva-barber` |
| rulo@lacueva.com | 123456 | La Cueva Barber (**barbero**, empleado) | |
| nico@eltano.com | 123456 | Barbería El Tano (dueño) | `/reservar/barberia-el-tano` |

## Cómo está organizado

```
src/
├── views/          pantallas (una por ruta)
├── components/     TurnoForm y ServicioForm (alta, edición y baja)
├── router/         rutas y protección con login
├── services/
│   ├── db.js       TODAS las consultas a la base
│   └── dbDemo.js   lo mismo pero en el navegador (modo demo)
├── utils/          fechas, precios, validaciones y búsqueda
├── composables/    useHideOnScroll (header que se esconde)
└── supabase.js     conexión a Supabase (o login de demo)
supabase/
├── schema.sql              tablas, relaciones, RLS por rol, trigger y funciones de reserva
├── actualizacion.sql       Parte 6, para una base existente (no borra datos)
├── actualizacion-parte7.sql Parte 7: permisos por rol (no borra datos)
└── seed.sql          2 barberías de prueba
docs/
├── SaaS-Parte5.md    diseño de la base: DER, roles y diccionario de datos
├── SaaS-Parte6.md    función principal (reservar un turno), recorrido y pruebas
└── SaaS-Parte7.md    ABM completo, búsqueda, roles y permisos, pruebas por rol
```

## Cómo cuido los datos de cada barbería

- Todas las tablas tienen `barberia_id`, y las **claves foráneas compuestas** impiden mezclar datos de dos barberías en un mismo turno.
- **RLS**: cada usuario solo ve y toca las filas de su barbería, y dentro de ella solo lo que le permite su rol (dueño o barbero). Ni cambiándose el rol desde la API se saltea.
- El cliente sin cuenta **no puede leer ni escribir tablas directo**. Reserva a través de dos funciones de la base (`horarios_disponibles` y `reservar_turno`) que validan todo antes de guardar.
- Un índice único no deja dar dos turnos al mismo barbero a la misma hora, ni aunque dos personas reserven en el mismo segundo.

## Pendiente

- Recordatorio automático por WhatsApp.
- Pantallas para editar los horarios y los datos de la barbería (los permisos en la base ya están: solo el dueño).
- Que el dueño invite barberos empleados desde la app.
- Publicarlo en Vercel.
