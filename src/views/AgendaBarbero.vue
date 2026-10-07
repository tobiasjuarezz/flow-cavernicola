<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { supabase } from "@/supabase";
import TurnoForm from "../components/TurnoForm.vue";

// Fecha de hoy en hora local (toISOString solo da UTC y después de las
// 21 hs en Argentina ya te devolvería el día siguiente)
function fechaDeHoy() {
  const d = new Date();
  d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
  return d.toISOString().slice(0, 10);
}

const turnos = ref([]);
const fecha = ref(fechaDeHoy());
const cargando = ref(true);
const error = ref("");
const nombreBarberia = ref("");

const formAbierto = ref(false);
const turnoEditando = ref(null);

const turnosActivos = computed(
  () => turnos.value.filter((t) => t.estado !== "cancelado").length
);

// LECTURA: trae los turnos del día elegido, ordenados por hora
async function cargarTurnos() {
  cargando.value = true;
  error.value = "";

  const { data, error: err } = await supabase
    .from("turnos")
    .select("*")
    .eq("fecha", fecha.value)
    .order("hora", { ascending: true });

  cargando.value = false;

  if (err) {
    error.value = "No se pudieron cargar los turnos.";
    return;
  }

  turnos.value = data;
}

onMounted(async () => {
  const { data } = await supabase.auth.getUser();
  nombreBarberia.value = data.user?.user_metadata?.barberia || "Mi barbería";
  cargarTurnos();
});

// Cada vez que cambio la fecha, recargo la agenda
watch(fecha, cargarTurnos);

function iniciales(nombre) {
  return nombre
    .split(" ")
    .filter(Boolean)
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
}

function abrirAlta() {
  turnoEditando.value = null;
  formAbierto.value = true;
}

function abrirEdicion(turno) {
  turnoEditando.value = turno;
  formAbierto.value = true;
}

function cerrarForm() {
  formAbierto.value = false;
  turnoEditando.value = null;
}

function alGuardar() {
  cerrarForm();
  cargarTurnos();
}

function compartirLink() {
  const link = `${window.location.origin}/reservar`;
  navigator.clipboard?.writeText(link);
  alert("Link de reserva copiado:\n" + link);
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Agenda</h2>
      <p>{{ nombreBarberia }}</p>
    </div>

    <div class="card">
      <div class="form-group" style="margin-bottom: 14px;">
        <label>Día</label>
        <input v-model="fecha" type="date" />
      </div>

      <div class="card-header">
        <div>
          <strong>{{ turnosActivos }} turnos activos</strong>
          <div class="muted">Tocá un turno para editarlo</div>
        </div>
        <div style="display: flex; gap: 8px; flex-wrap: wrap;">
          <button class="btn btn-primary" @click="abrirAlta">+ Nuevo turno</button>
          <button class="btn btn-secondary" @click="compartirLink">Compartir link</button>
        </div>
      </div>
    </div>

    <p v-if="cargando" class="muted center-text">Cargando turnos...</p>
    <p v-else-if="error" class="error-text center-text">{{ error }}</p>

    <div v-else-if="turnos.length === 0" class="card turno-libre center-text">
      <p class="muted" style="margin: 6px 0;">No hay turnos para este día.</p>
    </div>

    <template v-else>
      <div
        v-for="turno in turnos"
        :key="turno.id"
        class="card turno-card"
        :style="turno.estado === 'cancelado' ? 'opacity: 0.55;' : ''"
        @click="abrirEdicion(turno)"
      >
        <div class="timeline-item">
          <div class="timeline-hora">{{ turno.hora.slice(0, 5) }}</div>

          <div class="avatar">{{ iniciales(turno.cliente) }}</div>

          <div class="turno-info">
            <strong>{{ turno.cliente }}</strong>
            <div class="muted">{{ turno.servicio }}</div>
          </div>

          <span class="badge" :class="'badge-' + turno.estado">
            {{ turno.estado }}
          </span>
        </div>
      </div>
    </template>

    <TurnoForm
      v-if="formAbierto"
      :turno="turnoEditando"
      :fecha-inicial="fecha"
      @cerrar="cerrarForm"
      @guardado="alGuardar"
    />
  </div>
</template>