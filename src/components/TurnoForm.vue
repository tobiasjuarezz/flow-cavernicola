<script setup>
import { ref, reactive, computed, onMounted } from "vue";
import {
  listarServicios,
  listarBarberos,
  guardarCliente,
  crearTurno,
  actualizarTurno,
  eliminarTurno,
} from "@/services/db";
import { horaCorta, precio } from "@/utils/fechas";
import { validarNombre, validarTelefono } from "@/utils/validaciones";

const props = defineProps({
  turno: { type: Object, default: null }, // null = alta, con datos = edición
  fechaInicial: { type: String, required: true },
  barberiaId: { type: String, required: true },
  perfilId: { type: String, required: true }, // el barbero logueado
  rol: { type: String, default: "dueno" }, // "dueno" o "barbero"
});
const emit = defineEmits(["cerrar", "guardado"]);

const esEdicion = computed(() => props.turno !== null);

// El dueño elige a qué barbero le da el turno y puede eliminarlo.
// El barbero solo carga turnos para sí mismo y no elimina (los cancela).
// La base controla lo mismo con RLS, por si alguien saltea la pantalla.
const esDueno = computed(() => props.rol === "dueno");

// Los servicios y barberos ahora salen de la base (antes era una lista fija)
const servicios = ref([]);
const barberos = ref([]);

// El turno viene con cliente, servicio y barbero unidos (ver db.js)
const form = reactive({
  fecha: props.turno?.fecha ?? props.fechaInicial,
  hora: horaCorta(props.turno?.hora),
  clienteNombre: props.turno?.cliente?.nombre ?? "",
  clienteTelefono: props.turno?.cliente?.telefono ?? "",
  servicioId: props.turno?.servicio?.id ?? null,
  perfilId: props.turno?.barbero?.id ?? props.perfilId,
  estado: props.turno?.estado ?? "pendiente",
  notas: props.turno?.notas ?? "",
});

const error = ref("");
const guardando = ref(false);
const confirmandoBorrado = ref(false);

onMounted(async () => {
  const [respServicios, respBarberos] = await Promise.all([
    listarServicios(props.barberiaId),
    listarBarberos(props.barberiaId),
  ]);

  if (respServicios.error || respBarberos.error) {
    error.value = "No se pudieron cargar los servicios.";
    return;
  }

  // Muestro los activos (y el del turno, por si lo desactivaron después)
  servicios.value = respServicios.data.filter((s) => s.activo || s.id === form.servicioId);
  barberos.value = respBarberos.data;

  if (!form.servicioId && servicios.value.length > 0) {
    form.servicioId = servicios.value[0].id;
  }
});

function traducirError(err) {
  // 23505 = se rompió el índice "turnos_sin_pisar" (turno repetido)
  if (err.code === "23505") return "Ese barbero ya tiene un turno ese día a esa hora.";
  // SIN_PERMISO lo arma db.js; 42501 es el error de RLS al insertar
  if (err.code === "SIN_PERMISO" || err.code === "42501") return "No tenés permiso para hacer eso.";
  return "No se pudo guardar el turno. Probá de nuevo.";
}

// ALTA y MODIFICACIÓN
async function guardar() {
  error.value = "";

  const nombre = form.clienteNombre.trim();
  const telefono = form.clienteTelefono.trim();

  if (!form.fecha || !form.hora || !nombre || !telefono || !form.servicioId) {
    error.value = "Completá fecha, hora, cliente, teléfono y servicio.";
    return;
  }

  // Además de que estén, que tengan el formato correcto
  const errorDatos = validarNombre(nombre) || validarTelefono(telefono);
  if (errorDatos) {
    error.value = errorDatos;
    return;
  }

  guardando.value = true;

  // 1) El cliente es una tabla aparte: lo busco por teléfono o lo creo
  const cliente = await guardarCliente(props.barberiaId, nombre, telefono);
  if (cliente.error) {
    guardando.value = false;
    error.value = traducirError(cliente.error);
    return;
  }

  // 2) El turno guarda los ids, no los textos
  const datos = {
    cliente_id: cliente.data.id,
    servicio_id: form.servicioId,
    perfil_id: form.perfilId,
    fecha: form.fecha,
    hora: form.hora,
    estado: form.estado,
    notas: form.notas.trim() || null,
  };

  const { error: err } = esEdicion.value
    ? await actualizarTurno(props.turno.id, datos)
    : await crearTurno({ barberia_id: props.barberiaId, ...datos });

  guardando.value = false;

  if (err) {
    error.value = traducirError(err);
    return;
  }

  // Le aviso a la agenda qué pasó, así muestra el mensaje de éxito
  emit("guardado", esEdicion.value ? "Turno actualizado." : "Turno creado.");
}

// BAJA: primero pido confirmación (confirmandoBorrado) y después borro
async function eliminar() {
  guardando.value = true;
  const { error: err } = await eliminarTurno(props.turno.id);
  guardando.value = false;
  confirmandoBorrado.value = false;

  if (err) {
    error.value =
      err.code === "SIN_PERMISO" ? "No tenés permiso para eliminar turnos." : "No se pudo eliminar el turno.";
    return;
  }

  emit("guardado", "Turno eliminado.");
}
</script>

<template>
  <div class="overlay" @click.self="emit('cerrar')">
    <form class="modal card" novalidate @submit.prevent="guardar">
      <div class="page-title" style="margin-bottom: 12px;">
        <h2 style="font-size: 24px;">
          {{ esEdicion ? "Editar turno" : "Nuevo turno" }}
        </h2>
      </div>

      <div class="fila">
        <div class="form-group">
          <label>Fecha</label>
          <input v-model="form.fecha" type="date" />
        </div>
        <div class="form-group">
          <label>Hora</label>
          <input v-model="form.hora" type="time" step="900" />
        </div>
      </div>

      <div class="form-group">
        <label>Cliente</label>
        <input v-model="form.clienteNombre" type="text" placeholder="Nombre del cliente" />
      </div>

      <div class="form-group">
        <label>Teléfono</label>
        <input v-model="form.clienteTelefono" type="tel" placeholder="11 1234-5678" />
      </div>

      <div class="form-group">
        <label>Servicio</label>
        <select v-model="form.servicioId">
          <option v-for="s in servicios" :key="s.id" :value="s.id">
            {{ s.nombre }} — {{ precio(s.precio) }}
          </option>
        </select>
      </div>

      <div v-if="esDueno && barberos.length > 1" class="form-group">
        <label>Barbero</label>
        <select v-model="form.perfilId">
          <option v-for="b in barberos" :key="b.id" :value="b.id">{{ b.nombre }}</option>
        </select>
      </div>

      <div v-if="esEdicion" class="form-group">
        <label>Estado</label>
        <select v-model="form.estado">
          <option value="pendiente">Pendiente</option>
          <option value="confirmado">Confirmado</option>
          <option value="completado">Completado</option>
          <option value="cancelado">Cancelado</option>
        </select>
      </div>

      <div class="form-group">
        <label>Notas (opcional)</label>
        <input v-model="form.notas" type="text" placeholder="Ej: viene con el hijo" />
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>

      <!-- Confirmación antes de eliminar -->
      <div v-if="confirmandoBorrado" class="confirmar-borrado">
        <p>
          ¿Seguro que querés eliminar el turno de <strong>{{ turno.cliente?.nombre }}</strong>?
          No se puede deshacer.
        </p>
        <div style="display: flex; gap: 8px;">
          <button class="btn btn-danger" type="button" :disabled="guardando" @click="eliminar">
            Sí, eliminar
          </button>
          <button class="btn btn-secondary" type="button" @click="confirmandoBorrado = false">
            No
          </button>
        </div>
      </div>

      <div v-else style="display: flex; gap: 8px; margin-top: 6px; flex-wrap: wrap;">
        <button class="btn btn-primary" type="submit" :disabled="guardando">
          {{ guardando ? "Guardando..." : "Guardar" }}
        </button>
        <button
          v-if="esEdicion && esDueno"
          class="btn btn-danger"
          type="button"
          :disabled="guardando"
          @click="confirmandoBorrado = true"
        >
          Eliminar
        </button>
        <button class="btn btn-secondary" type="button" @click="emit('cerrar')">
          Cancelar
        </button>
      </div>
    </form>
  </div>
</template>

<style scoped>
.modal {
  max-height: 90vh;
  overflow-y: auto;
}

.fila {
  display: flex;
  gap: 10px;
}

.fila .form-group {
  flex: 1;
}

.confirmar-borrado {
  background: var(--peligro-bg);
  border-radius: 10px;
  padding: 12px 14px;
  margin-top: 6px;
}

.confirmar-borrado p {
  margin: 0 0 10px;
  font-size: 13.5px;
}
</style>
