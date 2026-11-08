// =====================================================================
//  src/utils/fechas.js
//  Funciones chicas para manejar fechas y horas. Antes la función de
//  "fecha de hoy" estaba copiada en dos archivos; ahora está acá sola.
// =====================================================================

// Devuelve la fecha en hora local con el formato que usa la base: "2026-11-08".
// OJO: toISOString() sola da la fecha en UTC, y después de las 21 hs en
// Argentina ya te devolvería el día siguiente. Por eso le resto el desfase.
export function fechaLocal(d = new Date()) {
  const copia = new Date(d);
  copia.setMinutes(copia.getMinutes() - copia.getTimezoneOffset());
  return copia.toISOString().slice(0, 10);
}

export function hoy() {
  return fechaLocal();
}

// sumarDias("2026-11-08", 1) -> "2026-11-09"
// (uso el mediodía para que el cambio de horario no me corra el día)
export function sumarDias(fechaTexto, dias) {
  const d = new Date(fechaTexto + "T12:00:00");
  d.setDate(d.getDate() + dias);
  return fechaLocal(d);
}

// "2026-11-10" -> "martes 10 de noviembre"
export function fechaLarga(fechaTexto) {
  if (!fechaTexto) return "";
  return new Date(fechaTexto + "T12:00:00").toLocaleDateString("es-AR", {
    weekday: "long",
    day: "numeric",
    month: "long",
  });
}

// "2026-11-10" -> "mar 10"
export function fechaCorta(fechaTexto) {
  return new Date(fechaTexto + "T12:00:00")
    .toLocaleDateString("es-AR", { weekday: "short", day: "numeric" })
    .replace(".", "");
}

// La base devuelve la hora como "09:00:00"; en pantalla muestro "09:00"
export function horaCorta(hora) {
  return hora ? hora.slice(0, 5) : "";
}

// 9000 -> "$ 9.000"
export function precio(numero) {
  return new Intl.NumberFormat("es-AR", {
    style: "currency",
    currency: "ARS",
    maximumFractionDigits: 0,
  }).format(numero);
}
