// =====================================================================
//  src/utils/buscar.js
//  Ayudas para comparar textos en las búsquedas.
// =====================================================================

// "Martína SOSA " -> "martina sosa" (sin tildes, en minúscula, sin espacios
// de más), así "martina" encuentra a "Martína"
export function normalizar(texto = "") {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .trim();
}

// "11 6123-4567" -> "1161234567", así se puede buscar un teléfono
// sin importar cómo se escribió
export function soloDigitos(texto = "") {
  return texto.replace(/\D/g, "");
}
