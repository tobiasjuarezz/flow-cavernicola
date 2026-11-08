<script setup>
import { ref, reactive, computed } from "vue";
import { guardarServicio, eliminarServicio } from "@/services/db";
import { validarServicio } from "@/utils/validaciones";

const props = defineProps({
  servicio: { type: Object, default: null }, // null = alta, con datos = edición
  barberiaId: { type: String, required: true },
});
const emit = defineEmits(["cerrar", "guardado"]);

const esEdicion = computed(() => props.servicio !== null);

const form = reactive({
  nombre: props.servicio?.nombre ?? "",
  duracion_min: props.servicio?.duracion_min ?? 30,
  precio: props.servicio?.precio ?? "",
  activo: props.servicio?.activo ?? true,
});

const error = ref("");
const guardando = ref(false);
const confirmandoBorrado = ref(false);

function traducirError(err) {
  // 23505 = unique (barberia_id, nombre): ya hay uno con ese nombre
  if (err.code === "23505") return "Ya tenés un servicio con ese nombre.";
  // 23503 = clave foránea: hay turnos que usan este servicio
  if (err.code === "23503") {
    return "Este servicio tiene turnos cargados. Desactivalo en vez de eliminarlo.";
  }
  if (err.code === "SIN_PERMISO" || err.code === "42501") return "No tenés permiso para hacer eso.";
  return "No se pudo guardar el servicio. Probá de nuevo.";
}

// ALTA y MODIFICACIÓN: las dos pasan por las mismas reglas
async function guardar() {
  error.value = "";

  const errorDatos = validarServicio(form);
  if (errorDatos) {
    error.value = errorDatos;
    return;
  }

  guardando.value = true;

  const datos = {
    barberia_id: props.barberiaId,
    nombre: form.nombre.trim(),
    duracion_min: Number(form.duracion_min),
    precio: Number(form.precio),
    activo: form.activo,
  };
  if (esEdicion.value) datos.id = props.servicio.id;

  const { error: err } = await guardarServicio(datos);

  guardando.value = false;

  if (err) {
    error.value = traducirError(err);
    return;
  }

  emit("guardado", esEdicion.value ? "Servicio actualizado." : "Servicio creado.");
}

// BAJA: primero confirmo
async function eliminar() {
  guardando.value = true;
  const { error: err } = await eliminarServicio(props.servicio.id);
  guardando.value = false;
  confirmandoBorrado.value = false;

  if (err) {
    error.value = traducirError(err);
    return;
  }

  emit("guardado", "Servicio eliminado.");
}
</script>

<template>
  <div class="overlay" @click.self="emit('cerrar')">
    <form class="modal card" novalidate @submit.prevent="guardar">
      <div class="page-title" style="margin-bottom: 12px;">
        <h2 style="font-size: 24px;">
          {{ esEdicion ? "Editar servicio" : "Nuevo servicio" }}
        </h2>
      </div>

      <div class="form-group">
        <label>Nombre</label>
        <input v-model="form.nombre" type="text" maxlength="40" placeholder="Ej: Corte + barba" />
      </div>

      <div class="fila">
        <div class="form-group">
          <label>Duración (min)</label>
          <input v-model.number="form.duracion_min" type="number" min="5" max="480" step="5" />
        </div>
        <div class="form-group">
          <label>Precio ($)</label>
          <input v-model.number="form.precio" type="number" min="0" step="500" placeholder="9000" />
        </div>
      </div>

      <label v-if="esEdicion" class="check">
        <input v-model="form.activo" type="checkbox" />
        Activo (los clientes lo ven en la página de reservas)
      </label>

      <p v-if="error" class="error-text">{{ error }}</p>

      <!-- Confirmación antes de eliminar -->
      <div v-if="confirmandoBorrado" class="confirmar-borrado">
        <p>
          ¿Seguro que querés eliminar <strong>{{ servicio.nombre }}</strong>? No se puede deshacer.
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
          v-if="esEdicion"
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

.check {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 13.5px;
  margin-bottom: 16px;
  cursor: pointer;
}

.check input {
  width: 18px;
  height: 18px;
  accent-color: var(--negro);
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
