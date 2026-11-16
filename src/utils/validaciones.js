// =====================================================================
//  src/utils/validaciones.js
//  Controles de formato que uso en los formularios.
//  Cada función devuelve "" si el dato está bien, o el mensaje de
//  error para mostrarle al usuario si está mal.
// =====================================================================

// Nombre de una persona: letras, espacios, punto, apóstrofo o guion
export function validarNombre(nombre) {
  const limpio = nombre.trim();
  if (!limpio) return "Completá el nombre.";
  if (limpio.length < 2) return "El nombre es muy corto.";
  // \p{L} = cualquier letra, incluidas las que tienen tilde y la ñ
  if (!/^[\p{L} .'-]+$/u.test(limpio)) return "El nombre solo puede tener letras.";
  return "";
}

// Acepta "11 1234-5678", "+54 9 11 1234-5678" o "1112345678"
export function validarTelefono(telefono) {
  const limpio = telefono.trim();
  if (!limpio) return "Completá el teléfono.";
  if (!/^[+\d\s()-]+$/.test(limpio)) {
    return "El teléfono solo puede tener números, espacios, guiones o +.";
  }
  const digitos = limpio.replace(/\D/g, "").length; // cuento solo los números
  if (digitos < 8 || digitos > 15) return "El teléfono tiene que tener entre 8 y 15 números.";
  return "";
}

export function validarEmail(email) {
  const limpio = email.trim();
  if (!limpio) return "Completá el email.";
  // algo@algo.algo, sin espacios
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(limpio)) return "El email no tiene un formato válido.";
  return "";
}

// Servicio de la barbería: las mismas reglas al crear y al modificar
export function validarServicio({ nombre, duracion_min, precio }) {
  const limpio = (nombre ?? "").trim();
  if (!limpio) return "Completá el nombre del servicio.";
  if (limpio.length < 2) return "El nombre del servicio es muy corto.";
  if (limpio.length > 40) return "El nombre del servicio puede tener hasta 40 caracteres.";

  if (duracion_min === "" || duracion_min === null || duracion_min === undefined) {
    return "Completá la duración.";
  }
  if (!Number.isInteger(Number(duracion_min)) || duracion_min < 5 || duracion_min > 480) {
    return "La duración tiene que ser un número entero de minutos, entre 5 y 480.";
  }

  if (precio === "" || precio === null || precio === undefined) return "Completá el precio.";
  if (!Number.isInteger(Number(precio)) || precio < 0 || precio > 10000000) {
    return "El precio tiene que ser un número entero, sin puntos ni comas, y no puede ser negativo.";
  }
  return "";
}

// Datos de la barbería (pantalla "Mi barbería"). El teléfono y la
// dirección son opcionales, pero si se completan tienen que estar bien.
export function validarBarberia({ nombre, telefono, direccion }) {
  const limpio = (nombre ?? "").trim();
  if (!limpio) return "Completá el nombre de la barbería.";
  if (limpio.length < 2) return "El nombre de la barbería es muy corto.";
  if (limpio.length > 60) return "El nombre de la barbería puede tener hasta 60 caracteres.";

  if ((telefono ?? "").trim()) {
    const errorTelefono = validarTelefono(telefono);
    if (errorTelefono) return errorTelefono;
  }

  if ((direccion ?? "").trim().length > 100) return "La dirección puede tener hasta 100 caracteres.";
  return "";
}

// Una franja de horario: "desde" tiene que ser antes que "hasta" y no
// puede pisarse con otra franja del mismo barbero el mismo día.
// "otras" son las demás franjas de ese barbero (sin la que se edita).
// Las horas vienen como "10:00", y como texto se pueden comparar.
export function validarHorario({ dia_semana, hora_inicio, hora_fin }, otras = []) {
  if (dia_semana === "" || dia_semana === null || dia_semana === undefined) return "Elegí el día.";
  if (!hora_inicio || !hora_fin) return "Completá la hora de inicio y la de fin.";
  // Los turnos se ofrecen cada 30 minutos: si la franja arranca 10:15,
  // los clientes verían horas raras (10:15, 10:45...)
  const enPuntoOYMedia = (hora) => ["00", "30"].includes(hora.slice(3, 5));
  if (!enPuntoOYMedia(hora_inicio) || !enPuntoOYMedia(hora_fin)) {
    return "Usá horas en punto o y media (por ejemplo 10:00 o 10:30).";
  }
  if (hora_fin <= hora_inicio) return "La hora de fin tiene que ser después de la de inicio.";

  const seSuperpone = otras.some(
    (h) =>
      Number(h.dia_semana) === Number(dia_semana) &&
      hora_inicio < h.hora_fin.slice(0, 5) &&
      h.hora_inicio.slice(0, 5) < hora_fin
  );
  if (seSuperpone) return "Esa franja se superpone con otra del mismo barbero ese día.";
  return "";
}
