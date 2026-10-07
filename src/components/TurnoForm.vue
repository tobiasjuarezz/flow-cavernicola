<script setup>
import { ref, reactive, computed } from "vue";
import { supabase } from "@/supabase";

const props = defineProps({
  turno: { type: Object, default: null }, // null = alta, con datos = edición
  fechaInicial: { type: String, required: true },
});
const emit = defineEmits(["cerrar", "guardado"]);

const servicios = [
  "Corte clásico",
  "Corte + barba",
  "Corte + diseño",
  "Barba",
  "Corte niño",
];

const esEdicion = computed(() => props.turno !== null);

const form = reactive({
  fecha: props.turno?.fecha ?? props.fechaInicial,
  hora: props.turno?.hora?.slice(0, 5) ?? "",
  cliente: props.turno?.cliente ?? "",
  telefono: props.turno?.telefono ?? "",
  servicio: props.turno?.servicio ?? servicios[0],
  estado: props.turno?.estado ?? "pendiente",
});

const error = ref("");
const guardando = ref(false);

function traducirError(err) {
  // 23505 = se rompió el índice "turnos_sin_pisar" (turno repetido)
  if (err.code === "23505") return "Ya tenés un turno ese día a esa hora.";
  return "No se pudo guardar el turno. Probá de nuevo.";
}

// ALTA y MODIFICACIÓN
async function guardar() {
  error.value = "";

  if (!form.fecha || !form.hora || !form.cliente.trim() || !form.telefono.trim()) {
    error.value = "Completá fecha, hora, cliente y teléfono.";
    return;
  }

  const datos = {
    fecha: form.fecha,
    hora: form.hora,
    cliente: form.cliente.trim(),
    telefono: form.telefono.trim(),
    servicio: form.servicio,
    estado: form.estado,
  };

  guardando.value = true;

  const { error: err } = esEdicion.value
    ? await supabase.from("turnos").update(datos).eq("id", props.turno.id)
    : await supabase.from("turnos").insert(datos);

  guardando.value = false;

  if (err) {
    error.value = traducirError(err);
    return;
  }

  emit("guardado");
}

// BAJA
async function eliminar() {
  if (!confirm(`¿Eliminar el turno de ${props.turno.cliente}?`)) return;

  guardando.value = true;

  const { error: err } = await supabase
    .from("turnos")
    .delete()
    .eq("id", props.turno.id);

  guardando.value = false;

  if (err) {
    error.value = "No se pudo eliminar el turno.";
    return;
  }

  emit("guardado");
}
</script>

<template>
  <div class="overlay" @click.self="emit('cerrar')">
    <form class="modal card" @submit.prevent="guardar">
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
        <input v-model="form.cliente" type="text" placeholder="Nombre del cliente" />
      </div>

      <div class="form-group">
        <label>Teléfono</label>
        <input v-model="form.telefono" type="tel" placeholder="11 1234-5678" />
      </div>

      <div class="form-group">
        <label>Servicio</label>
        <select v-model="form.servicio">
          <option v-for="s in servicios" :key="s" :value="s">{{ s }}</option>
        </select>
      </div>

      <div v-if="esEdicion" class="form-group">
        <label>Estado</label>
        <select v-model="form.estado">
          <option value="pendiente">Pendiente</option>
          <option value="completado">Completado</option>
          <option value="cancelado">Cancelado</option>
        </select>
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>

      <div style="display: flex; gap: 8px; margin-top: 6px; flex-wrap: wrap;">
        <button class="btn btn-primary" type="submit" :disabled="guardando">
          {{ guardando ? "Guardando..." : "Guardar" }}
        </button>
        <button
          v-if="esEdicion"
          class="btn btn-danger"
          type="button"
          :disabled="guardando"
          @click="eliminar"
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

.form-group select {
  width: 100%;
  padding: 12px 14px;
  border: 1.5px solid var(--borde);
  border-radius: 10px;
  font-size: 14.5px;
  font-family: inherit;
  background: #fff;
}

.form-group select:focus {
  outline: none;
  border-color: var(--mostaza);
}
</style>