<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { horariosDisponibles, turnos } from "../data/turnos";

const router = useRouter();

const horarioSeleccionado = ref(null);
const nombre = ref("");
const telefono = ref("");
const error = ref("");

function elegirHorario(horario) {
  horarioSeleccionado.value = horario;
}

function confirmarReserva() {
  if (!horarioSeleccionado.value) {
    error.value = "Elegí un horario disponible.";
    return;
  }
  if (!nombre.value.trim() || !telefono.value.trim()) {
    error.value = "Completá tu nombre y tu teléfono.";
    return;
  }
  error.value = "";

  const nuevoId = Math.max(...turnos.map((t) => t.id)) + 1;
  turnos.push({
    id: nuevoId,
    hora: horarioSeleccionado.value,
    cliente: nombre.value,
    telefono: telefono.value,
    servicio: "A confirmar",
    estado: "pendiente",
  });

  router.push({
    name: "confirmacion",
    query: { hora: horarioSeleccionado.value, nombre: nombre.value },
  });
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Reservá tu turno</h2>
      <p>Barbería Flow Cavernícola</p>
    </div>

    <div class="card">
      <strong>Horarios de esta semana</strong>
      <div class="slots-grid">
        <div
          v-for="horario in horariosDisponibles"
          :key="horario"
          class="slot"
          :class="{ selected: horarioSeleccionado === horario }"
          @click="elegirHorario(horario)"
        >
          {{ horario }}
        </div>
      </div>
    </div>

    <div class="card">
      <div class="form-group">
        <label>Nombre</label>
        <input v-model="nombre" type="text" placeholder="Tu nombre" />
      </div>
      <div class="form-group">
        <label>Teléfono</label>
        <input v-model="telefono" type="tel" placeholder="11 1234-5678" />
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>

      <button class="btn btn-primary btn-block" @click="confirmarReserva">
        Confirmar turno
      </button>
    </div>
  </div>
</template>