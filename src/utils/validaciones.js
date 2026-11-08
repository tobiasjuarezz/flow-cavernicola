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
