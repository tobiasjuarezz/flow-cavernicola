# Flow Cavernícola ✂️

**Turnos sin vueltas.** Agenda de turnos online para barberías chicas.

Cada barbería tiene su propio link de reserva (por ejemplo `/reservar/la-cueva-barber`). El cliente entra, elige servicio, día y hora, y reserva **sin crearse una cuenta**. El barbero ve todo ordenado en su agenda.

Proyecto de la materia PDISC 7.6 — E.E.S. Técnica N°1, Esteban Echeverría.

## Qué hace

**Barbero (con cuenta)**
- Se registra con el nombre de su barbería. La base le crea sola la barbería, su link y unos servicios y horarios de arranque.
- Ve su agenda por día, con cliente, servicio, barbero y estado de cada turno.
- Crea, edita, cancela y elimina turnos.
- Copia o abre su link de reservas para compartirlo.

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

**¿Ya tenías la base creada?** No vuelvas a correr `schema.sql` (borra todo). Corré solo `supabase/actualizacion.sql`, que agrega lo nuevo sin tocar tus datos.

### Usuarios de prueba (del seed)

| Email | Contraseña | Barbería | Link de reservas |
|---|---|---|---|
| tano@lacueva.com | 123456 | La Cueva Barber (dueño) | `/reservar/la-cueva-barber` |
| rulo@lacueva.com | 123456 | La Cueva Barber (barbero) | |
| nico@eltano.com | 123456 | Barbería El Tano (dueño) | `/reservar/barberia-el-tano` |

## Cómo está organizado

```
src/
├── views/          pantallas (una por ruta)
├── components/     TurnoForm (alta y edición de turnos)
├── router/         rutas y protección con login
├── services/
│   ├── db.js       TODAS las consultas a la base
│   └── dbDemo.js   lo mismo pero en el navegador (modo demo)
├── utils/          fechas, horas y precios
├── composables/    useHideOnScroll (header que se esconde)
└── supabase.js     conexión a Supabase (o login de demo)
supabase/
├── schema.sql        tablas, relaciones, RLS, trigger y funciones de reserva
├── actualizacion.sql agrega lo nuevo a una base existente sin borrar datos
└── seed.sql          2 barberías de prueba
docs/
├── SaaS-Parte5.md    diseño de la base: DER, roles y diccionario de datos
└── SaaS-Parte6.md    función principal (reservar un turno), recorrido y pruebas
```

## Cómo cuido los datos de cada barbería

- Todas las tablas tienen `barberia_id`, y las **claves foráneas compuestas** impiden mezclar datos de dos barberías en un mismo turno.
- **RLS**: un barbero logueado solo ve y toca las filas de su barbería.
- El cliente sin cuenta **no puede leer ni escribir tablas directo**. Reserva a través de dos funciones de la base (`horarios_disponibles` y `reservar_turno`) que validan todo antes de guardar.
- Un índice único no deja dar dos turnos al mismo barbero a la misma hora, ni aunque dos personas reserven en el mismo segundo.

## Pendiente

- Recordatorio automático por WhatsApp.
- Pantallas para que el barbero edite sus servicios, precios y horarios (hoy quedan los de arranque).
- Sumar barberos empleados desde la app.
- Publicarlo en Vercel.
