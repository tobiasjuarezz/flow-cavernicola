// =====================================================================
//  src/services/dbDemo.js
//  MODO DEMO: las mismas funciones que db.js, pero sin Supabase.
//  Todo se guarda en el navegador (localStorage), así la app se puede
//  probar sin configurar nada. Imita lo que hace la base real:
//    - al primer login se crea la barbería con servicios y horarios
//      (como el trigger "al_registrarse_usuario")
//    - no deja dos turnos del mismo barbero a la misma hora
//      (como el índice "turnos_sin_pisar")
//    - la reserva pública hace las mismas validaciones que
//      la función reservar_turno() del SQL
//  OJO: como vive en el navegador, la página de reserva solo funciona
//  en el mismo navegador donde se registró la barbería.
// =====================================================================
import { supabase } from "@/supabase";

const CLAVE = "fc_demo_db";

function baseVacia() {
  return {
    barberias: [],
    perfiles: [],
    servicios: [],
    horarios: [],
    clientes: [],
    turnos: [],
    ultimoId: 0,
  };
}

function leer() {
  try {
    return JSON.parse(localStorage.getItem(CLAVE)) || baseVacia();
  } catch {
    return baseVacia();
  }
}

function guardar(db) {
  try {
    localStorage.setItem(CLAVE, JSON.stringify(db));
  } catch {
    // si el navegador no deja guardar, sigue andando hasta que recargues
  }
}

function nuevoId(db) {
  db.ultimoId += 1;
  return db.ultimoId;
}

const ok = (data) => ({ data, error: null });
const falla = (message, code) => ({ data: null, error: { message, code } });

// "09:30" -> 570 minutos, y al revés
const aMinutos = (hora) => Number(hora.slice(0, 2)) * 60 + Number(hora.slice(3, 5));
const aHora = (min) =>
  String(Math.floor(min / 60)).padStart(2, "0") + ":" + String(min % 60).padStart(2, "0");

// La base guarda la hora como "09:30:00"
const normalizarHora = (hora) => (hora.length === 5 ? hora + ":00" : hora);

function yaPaso(fecha, hora) {
  return new Date(`${fecha}T${hora.slice(0, 5)}:00`) <= new Date();
}

function generarSlug(texto) {
  return texto
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "") // saca tildes
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");
}

// ---------------------------------------------------------------------
// Imita el trigger del SQL: si el usuario logueado todavía no tiene
// perfil, le creo su barbería, su perfil de dueño y los datos iniciales
// ---------------------------------------------------------------------
async function miPerfil(db) {
  const { data } = await supabase.auth.getUser();
  const usuario = data.user;
  if (!usuario) return null;

  let perfil = db.perfiles.find((p) => p.id === usuario.id);
  if (perfil) return perfil;

  const nombreBarberia = usuario.user_metadata?.barberia?.trim() || "Mi barbería";
  const base = generarSlug(nombreBarberia) || "barberia";
  let slug = base;
  while (db.barberias.some((b) => b.slug === slug)) {
    slug = base + "-" + Math.floor(Math.random() * 9000 + 1000);
  }

  const barberia = {
    id: "barberia-" + nuevoId(db),
    nombre: nombreBarberia,
    slug,
    telefono: null,
    direccion: null,
    plan: "gratis",
  };
  db.barberias.push(barberia);

  perfil = {
    id: usuario.id,
    barberia_id: barberia.id,
    nombre: usuario.user_metadata?.nombre?.trim() || usuario.email.split("@")[0],
    telefono: null,
    rol: "dueno",
    activo: true,
  };
  db.perfiles.push(perfil);

  // Igual que cargar_datos_iniciales() del SQL
  [
    ["Corte clásico", 30, 9000],
    ["Corte + barba", 45, 13000],
    ["Barba", 20, 6000],
  ].forEach(([nombre, duracion_min, precio]) => {
    db.servicios.push({
      id: nuevoId(db),
      barberia_id: barberia.id,
      nombre,
      duracion_min,
      precio,
      activo: true,
    });
  });

  for (let dia = 1; dia <= 6; dia++) {
    db.horarios.push({
      id: nuevoId(db),
      barberia_id: barberia.id,
      perfil_id: perfil.id,
      dia_semana: dia,
      hora_inicio: "10:00:00",
      hora_fin: "20:00:00",
    });
  }

  guardar(db);
  return perfil;
}

// Los turnos de un barbero que ocupan esa fecha y hora (sin contar cancelados)
function estaOcupado(db, perfilId, fecha, hora, idIgnorado = null) {
  return db.turnos.some(
    (t) =>
      t.id !== idIgnorado &&
      t.perfil_id === perfilId &&
      t.fecha === fecha &&
      t.hora === normalizarHora(hora) &&
      t.estado !== "cancelado"
  );
}

// ---------------------------------------------------------------------
// PERFIL / BARBERÍA
// ---------------------------------------------------------------------
export async function obtenerMiPerfil() {
  const db = leer();
  const perfil = await miPerfil(db);
  if (!perfil) return falla("No hay sesión");

  const b = db.barberias.find((x) => x.id === perfil.barberia_id);
  return ok({
    id: perfil.id,
    nombre: perfil.nombre,
    telefono: perfil.telefono,
    rol: perfil.rol,
    barberia: { id: b.id, nombre: b.nombre, slug: b.slug, plan: b.plan },
  });
}

export async function buscarBarberiaPorSlug(slug) {
  const b = leer().barberias.find((x) => x.slug === slug);
  return ok(
    b ? { id: b.id, nombre: b.nombre, slug: b.slug, telefono: b.telefono, direccion: b.direccion } : null
  );
}

// ---------------------------------------------------------------------
// SERVICIOS y BARBEROS
// ---------------------------------------------------------------------
export async function listarServicios(barberiaId) {
  const lista = leer()
    .servicios.filter((s) => s.barberia_id === barberiaId)
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
    .map(({ id, nombre, duracion_min, precio, activo }) => ({ id, nombre, duracion_min, precio, activo }));
  return ok(lista);
}

export async function listarBarberos(barberiaId) {
  const lista = leer()
    .perfiles.filter((p) => p.barberia_id === barberiaId && p.activo)
    .sort((a, b) => a.nombre.localeCompare(b.nombre))
    .map(({ id, nombre }) => ({ id, nombre }));
  return ok(lista);
}

// ---------------------------------------------------------------------
// CLIENTES
// ---------------------------------------------------------------------
export async function guardarCliente(barberiaId, nombre, telefono) {
  const db = leer();
  const perfil = await miPerfil(db);
  if (!perfil || perfil.barberia_id !== barberiaId) return falla("No autorizado");

  let cliente = db.clientes.find((c) => c.barberia_id === barberiaId && c.telefono === telefono);
  if (cliente) {
    cliente.nombre = nombre;
  } else {
    cliente = { id: nuevoId(db), barberia_id: barberiaId, nombre, telefono };
    db.clientes.push(cliente);
  }
  guardar(db);
  return ok({ id: cliente.id, nombre: cliente.nombre, telefono: cliente.telefono });
}

// ---------------------------------------------------------------------
// TURNOS (panel del barbero)
// ---------------------------------------------------------------------
export async function listarTurnosDelDia(barberiaId, fecha) {
  const db = leer();
  const perfil = await miPerfil(db);
  if (!perfil || perfil.barberia_id !== barberiaId) return falla("No autorizado");

  const lista = db.turnos
    .filter((t) => t.barberia_id === barberiaId && t.fecha === fecha)
    .sort((a, b) => a.hora.localeCompare(b.hora))
    .map((t) => {
      const c = db.clientes.find((x) => x.id === t.cliente_id);
      const s = db.servicios.find((x) => x.id === t.servicio_id);
      const p = db.perfiles.find((x) => x.id === t.perfil_id);
      return {
        id: t.id,
        fecha: t.fecha,
        hora: t.hora,
        estado: t.estado,
        notas: t.notas,
        cliente: c ? { id: c.id, nombre: c.nombre, telefono: c.telefono } : null,
        servicio: s
          ? { id: s.id, nombre: s.nombre, duracion_min: s.duracion_min, precio: s.precio }
          : null,
        barbero: p ? { id: p.id, nombre: p.nombre } : null,
      };
    });
  return ok(lista);
}

export async function crearTurno(turno) {
  const db = leer();
  const perfil = await miPerfil(db);
  if (!perfil || perfil.barberia_id !== turno.barberia_id) return falla("No autorizado");

  if (estaOcupado(db, turno.perfil_id, turno.fecha, turno.hora)) {
    return falla("duplicate key value", "23505");
  }

  const nuevo = {
    estado: "pendiente",
    notas: null,
    ...turno,
    id: nuevoId(db),
    hora: normalizarHora(turno.hora),
  };
  db.turnos.push(nuevo);
  guardar(db);
  return ok(nuevo);
}

export async function actualizarTurno(id, cambios) {
  const db = leer();
  const perfil = await miPerfil(db);
  const turno = db.turnos.find((t) => t.id === id);
  if (!perfil || !turno || turno.barberia_id !== perfil.barberia_id) return falla("No autorizado");

  const resultado = { ...turno, ...cambios, id: turno.id, barberia_id: turno.barberia_id };
  resultado.hora = normalizarHora(resultado.hora);

  if (
    resultado.estado !== "cancelado" &&
    estaOcupado(db, resultado.perfil_id, resultado.fecha, resultado.hora, id)
  ) {
    return falla("duplicate key value", "23505");
  }

  Object.assign(turno, resultado);
  guardar(db);
  return ok(null);
}

export async function eliminarTurno(id) {
  const db = leer();
  const perfil = await miPerfil(db);
  if (!perfil) return falla("No autorizado");

  db.turnos = db.turnos.filter((t) => !(t.id === id && t.barberia_id === perfil.barberia_id));
  guardar(db);
  return ok(null);
}

// ---------------------------------------------------------------------
// RESERVA PÚBLICA (igual que las funciones del SQL, sección 9)
// ---------------------------------------------------------------------

// Barberos que trabajan ese día, con su franja horaria
function franjasDelDia(db, barberiaId, fecha) {
  const dia = new Date(fecha + "T12:00:00").getDay(); // 0 = domingo
  return db.horarios.filter((h) => {
    const p = db.perfiles.find((x) => x.id === h.perfil_id);
    return h.barberia_id === barberiaId && h.dia_semana === dia && p?.activo;
  });
}

export async function horariosDisponibles(slug, fecha) {
  const db = leer();
  const b = db.barberias.find((x) => x.slug === slug);
  if (!b) return ok([]);

  const libres = new Set();
  for (const h of franjasDelDia(db, b.id, fecha)) {
    for (let m = aMinutos(h.hora_inicio); m <= aMinutos(h.hora_fin) - 30; m += 30) {
      const hora = aHora(m);
      if (!yaPaso(fecha, hora) && !estaOcupado(db, h.perfil_id, fecha, hora)) {
        libres.add(hora);
      }
    }
  }
  return ok([...libres].sort());
}

export async function reservarTurno({ slug, servicioId, fecha, hora, nombre, telefono }) {
  const db = leer();
  nombre = nombre?.trim();
  telefono = telefono?.trim();

  if (!nombre || !telefono) return falla("Completá tu nombre y tu teléfono.");

  const b = db.barberias.find((x) => x.slug === slug);
  if (!b) return falla("Esa barbería no existe.");

  const servicio = db.servicios.find((s) => s.id === servicioId && s.barberia_id === b.id && s.activo);
  if (!servicio) return falla("Ese servicio no está disponible.");

  if (yaPaso(fecha, hora)) return falla("Ese horario ya pasó.");

  // Barbero que trabaja a esa hora y está libre; si hay varios,
  // el que tiene menos turnos ese día
  const minutos = aMinutos(hora);
  const cuantosTurnos = (perfilId) =>
    db.turnos.filter((t) => t.perfil_id === perfilId && t.fecha === fecha && t.estado !== "cancelado").length;

  const candidato = franjasDelDia(db, b.id, fecha)
    .filter(
      (h) =>
        minutos >= aMinutos(h.hora_inicio) &&
        minutos < aMinutos(h.hora_fin) &&
        !estaOcupado(db, h.perfil_id, fecha, hora)
    )
    .sort((x, y) => cuantosTurnos(x.perfil_id) - cuantosTurnos(y.perfil_id))[0];

  if (!candidato) return falla("Ese horario ya no está disponible.");

  // Si el teléfono ya es cliente, uso ese (sin pisarle el nombre)
  let cliente = db.clientes.find((c) => c.barberia_id === b.id && c.telefono === telefono);
  if (!cliente) {
    cliente = { id: nuevoId(db), barberia_id: b.id, nombre, telefono };
    db.clientes.push(cliente);
  }

  const turno = {
    id: nuevoId(db),
    barberia_id: b.id,
    cliente_id: cliente.id,
    servicio_id: servicio.id,
    perfil_id: candidato.perfil_id,
    fecha,
    hora: normalizarHora(hora),
    estado: "pendiente",
    notas: null,
  };
  db.turnos.push(turno);
  guardar(db);

  return ok({
    turno_id: turno.id,
    barberia: b.nombre,
    servicio: servicio.nombre,
    fecha,
    hora: hora.slice(0, 5),
  });
}
