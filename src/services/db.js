// =====================================================================
//  src/services/db.js
//  Acá centralizo TODAS las operaciones con la base de datos.
//  Las vistas y componentes no llaman a supabase.from(...) directo:
//  importan estas funciones. Si mañana cambia una tabla, toco solo acá.
//
//  Todas devuelven { data, error }, igual que Supabase.
// =====================================================================
import { supabase } from "@/supabase";

// ---------------------------------------------------------------------
// PERFIL / BARBERÍA del usuario logueado
// ---------------------------------------------------------------------

// Trae mi perfil junto con los datos de mi barbería
export async function obtenerMiPerfil() {
  const { data: auth } = await supabase.auth.getUser();
  if (!auth.user) return { data: null, error: { message: "No hay sesión" } };

  return supabase
    .from("perfiles")
    .select("id, nombre, telefono, rol, barberia:barberias(id, nombre, slug, plan)")
    .eq("id", auth.user.id)
    .single();
}

// Página pública: busco la barbería por el slug del link
export function buscarBarberiaPorSlug(slug) {
  return supabase
    .from("barberias")
    .select("id, nombre, slug, telefono, direccion")
    .eq("slug", slug)
    .single();
}

// ---------------------------------------------------------------------
// SERVICIOS
// ---------------------------------------------------------------------
export function listarServicios(barberiaId) {
  return supabase
    .from("servicios")
    .select("id, nombre, duracion_min, precio, activo")
    .eq("barberia_id", barberiaId)
    .order("nombre");
}

export function guardarServicio(servicio) {
  // si trae id es edición, si no es alta
  return servicio.id
    ? supabase.from("servicios").update(servicio).eq("id", servicio.id)
    : supabase.from("servicios").insert(servicio);
}

// ---------------------------------------------------------------------
// HORARIOS
// ---------------------------------------------------------------------
export function listarHorarios(barberiaId) {
  return supabase
    .from("horarios")
    .select("id, perfil_id, dia_semana, hora_inicio, hora_fin")
    .eq("barberia_id", barberiaId)
    .order("dia_semana")
    .order("hora_inicio");
}

// ---------------------------------------------------------------------
// CLIENTES
// ---------------------------------------------------------------------

// Si el teléfono ya existe en mi barbería devuelvo ese cliente,
// si no, lo creo. Así no se duplican clientes.
export async function obtenerOCrearCliente(barberiaId, nombre, telefono) {
  const existente = await supabase
    .from("clientes")
    .select("id, nombre, telefono")
    .eq("barberia_id", barberiaId)
    .eq("telefono", telefono)
    .maybeSingle();

  if (existente.error || existente.data) return existente;

  return supabase
    .from("clientes")
    .insert({ barberia_id: barberiaId, nombre, telefono })
    .select("id, nombre, telefono")
    .single();
}

// ---------------------------------------------------------------------
// TURNOS
// ---------------------------------------------------------------------

// Agenda de un día con los datos del cliente, servicio y barbero unidos
export function listarTurnosDelDia(barberiaId, fecha) {
  return supabase
    .from("turnos")
    .select(`
      id, fecha, hora, estado, notas,
      cliente:clientes(id, nombre, telefono),
      servicio:servicios(id, nombre, duracion_min, precio),
      barbero:perfiles(id, nombre)
    `)
    .eq("barberia_id", barberiaId)
    .eq("fecha", fecha)
    .order("hora");
}

export function crearTurno(turno) {
  // turno = { barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora }
  return supabase.from("turnos").insert(turno).select().single();
}

export function actualizarTurno(id, cambios) {
  return supabase.from("turnos").update(cambios).eq("id", id);
}

export function cambiarEstadoTurno(id, estado) {
  return actualizarTurno(id, { estado });
}

export function eliminarTurno(id) {
  return supabase.from("turnos").delete().eq("id", id);
}
