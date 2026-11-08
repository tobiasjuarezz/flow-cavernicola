// =====================================================================
//  src/services/db.js
//  Acá centralizo TODAS las operaciones con la base de datos.
//  Las vistas y componentes no llaman a supabase.from(...) directo:
//  importan estas funciones. Si mañana cambia una tabla, toco solo acá.
//
//  Todas devuelven { data, error }, igual que Supabase.
//
//  Modo demo: si no hay .env con datos de Supabase, en vez de estas
//  funciones se usan las de dbDemo.js, que tienen los MISMOS nombres
//  pero guardan todo en el navegador. Las vistas ni se enteran.
// =====================================================================
import { supabase, modoDemo } from "@/supabase";
import * as demo from "./dbDemo";

// Cuando las reglas de seguridad (RLS) no dejan modificar o borrar una
// fila, Supabase NO devuelve error: simplemente no toca ninguna fila.
// Por eso pido las filas afectadas con .select() y, si no vino ninguna,
// lo convierto en un error que la pantalla pueda mostrar.
async function exigirFilas(consulta) {
  const { data, error } = await consulta;
  if (error) return { data: null, error };
  if (!data || data.length === 0) {
    return {
      data: null,
      error: { code: "SIN_PERMISO", message: "No tenés permiso para hacer eso." },
    };
  }
  return { data, error: null };
}

const real = {
  // -------------------------------------------------------------------
  // PERFIL / BARBERÍA del usuario logueado
  // -------------------------------------------------------------------

  // Trae mi perfil junto con los datos de mi barbería
  async obtenerMiPerfil() {
    const { data: auth } = await supabase.auth.getUser();
    if (!auth.user) return { data: null, error: { message: "No hay sesión" } };

    return supabase
      .from("perfiles")
      .select("id, nombre, telefono, rol, barberia:barberias(id, nombre, slug, plan)")
      .eq("id", auth.user.id)
      .single();
  },

  // Página pública: busco la barbería por el slug del link.
  // maybeSingle() devuelve data = null si no existe (en vez de error)
  buscarBarberiaPorSlug(slug) {
    return supabase
      .from("barberias")
      .select("id, nombre, slug, telefono, direccion")
      .eq("slug", slug)
      .maybeSingle();
  },

  // -------------------------------------------------------------------
  // SERVICIOS y BARBEROS
  // -------------------------------------------------------------------
  listarServicios(barberiaId) {
    return supabase
      .from("servicios")
      .select("id, nombre, duracion_min, precio, activo")
      .eq("barberia_id", barberiaId)
      .order("nombre");
  },

  // Si trae id es edición, si no es alta. Solo el dueño puede (RLS).
  guardarServicio(servicio) {
    const { id, ...datos } = servicio;
    return id
      ? exigirFilas(supabase.from("servicios").update(datos).eq("id", id).select("id"))
      : supabase.from("servicios").insert(datos).select("id").single();
  },

  eliminarServicio(id) {
    return exigirFilas(supabase.from("servicios").delete().eq("id", id).select("id"));
  },

  listarBarberos(barberiaId) {
    return supabase
      .from("perfiles")
      .select("id, nombre")
      .eq("barberia_id", barberiaId)
      .eq("activo", true)
      .order("nombre");
  },

  // -------------------------------------------------------------------
  // CLIENTES
  // -------------------------------------------------------------------

  // "upsert" = insert o update en una sola llamada. Si el teléfono ya
  // es cliente de mi barbería, le actualizo el nombre; si no, lo creo.
  // Funciona gracias al unique (barberia_id, telefono) de la tabla.
  guardarCliente(barberiaId, nombre, telefono) {
    return supabase
      .from("clientes")
      .upsert(
        { barberia_id: barberiaId, nombre, telefono },
        { onConflict: "barberia_id,telefono" }
      )
      .select("id, nombre, telefono")
      .single();
  },

  // -------------------------------------------------------------------
  // TURNOS (panel del barbero)
  // -------------------------------------------------------------------

  // Turnos con cliente, servicio y barbero unidos.
  // filtros = { desde, hasta, estado }: todos opcionales.
  // La búsqueda por nombre y el orden los hace la pantalla sobre este
  // resultado, que ya viene filtrado por barbería (y por RLS).
  listarTurnos(barberiaId, { desde, hasta, estado } = {}) {
    let consulta = supabase
      .from("turnos")
      .select(`
        id, fecha, hora, estado, notas,
        cliente:clientes(id, nombre, telefono),
        servicio:servicios(id, nombre, duracion_min, precio),
        barbero:perfiles(id, nombre)
      `)
      .eq("barberia_id", barberiaId);

    if (desde) consulta = consulta.gte("fecha", desde);
    if (hasta) consulta = consulta.lte("fecha", hasta);
    if (estado) consulta = consulta.eq("estado", estado);

    return consulta.order("fecha").order("hora");
  },

  // Agenda de un solo día
  listarTurnosDelDia(barberiaId, fecha) {
    return real.listarTurnos(barberiaId, { desde: fecha, hasta: fecha });
  },

  crearTurno(turno) {
    // turno = { barberia_id, cliente_id, servicio_id, perfil_id, fecha, hora, estado, notas }
    return supabase.from("turnos").insert(turno).select().single();
  },

  // El barbero solo puede modificar sus turnos: si quiere tocar uno
  // ajeno, RLS no deja y exigirFilas() lo avisa
  actualizarTurno(id, cambios) {
    return exigirFilas(supabase.from("turnos").update(cambios).eq("id", id).select("id"));
  },

  // Solo el dueño puede eliminar
  eliminarTurno(id) {
    return exigirFilas(supabase.from("turnos").delete().eq("id", id).select("id"));
  },

  // -------------------------------------------------------------------
  // RESERVA PÚBLICA (el cliente no tiene cuenta)
  // Estas llaman a funciones de la base con rpc(). Ver schema.sql,
  // sección 9: corren "security definer" para saltear RLS de forma
  // controlada.
  // -------------------------------------------------------------------

  // Devuelve ["10:00", "10:30", ...] con las horas libres de ese día
  async horariosDisponibles(slug, fecha) {
    const { data, error } = await supabase.rpc("horarios_disponibles", {
      p_slug: slug,
      p_fecha: fecha,
    });
    return { data: (data ?? []).map((fila) => fila.hora.slice(0, 5)), error };
  },

  // Devuelve { turno_id, barberia, servicio, fecha, hora }
  reservarTurno({ slug, servicioId, fecha, hora, nombre, telefono }) {
    return supabase.rpc("reservar_turno", {
      p_slug: slug,
      p_servicio_id: servicioId,
      p_fecha: fecha,
      p_hora: hora,
      p_nombre: nombre,
      p_telefono: telefono,
    });
  },
};

// Acá se elige: base real o modo demo
const api = modoDemo ? demo : real;

export const {
  obtenerMiPerfil,
  buscarBarberiaPorSlug,
  listarServicios,
  guardarServicio,
  eliminarServicio,
  listarBarberos,
  guardarCliente,
  listarTurnos,
  listarTurnosDelDia,
  crearTurno,
  actualizarTurno,
  eliminarTurno,
  horariosDisponibles,
  reservarTurno,
} = api;
