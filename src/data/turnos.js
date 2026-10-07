// Datos de ejemplo (mock). Cuando conecte Supabase, esto se reemplaza por
// llamadas reales a la base de datos.
import { reactive } from "vue";

export const turnos = reactive([
  {
    id: 1,
    hora: "09:00",
    cliente: "Nahuel Cuatrano",
    telefono: "11 4444-1111",
    servicio: "Corte + barba",
    estado: "completado",
  },
  {
    id: 2,
    hora: "10:30",
    cliente: "Tomás Silvero",
    telefono: "11 4444-2222",
    servicio: "Corte clásico",
    estado: "completado",
  },
  {
    id: 3,
    hora: "12:00",
    cliente: "Santiago Battiston",
    telefono: "11 4444-3333",
    servicio: "Corte + diseño",
    estado: "pendiente",
  },
  {
    id: 4,
    hora: "16:00",
    cliente: "Sofía Aguilar",
    telefono: "11 4444-4444",
    servicio: "Corte niño",
    estado: "pendiente",
  },
  {
    id: 5,
    hora: "17:30",
    cliente: "—",
    telefono: "—",
    servicio: "—",
    estado: "libre",
  },
]);

export const horariosDisponibles = [
  "09:00", "09:30", "10:00", "10:30", "11:00", "11:30",
  "12:00", "12:30", "16:00", "16:30", "17:00", "17:30",
];