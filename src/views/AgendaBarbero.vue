<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { obtenerMiPerfil, listarTurnosDelDia } from "@/services/db";
import { hoy, horaCorta } from "@/utils/fechas";
import TurnoForm from "@/components/TurnoForm.vue";

const perfil = ref(null);
const turnos = ref([]);
const fecha = ref(hoy());
const cargando = ref(true);
const error = ref("");

const formAbierto = ref(false);
const turnoEditando = ref(null);
const linkCopiado = ref(false);
const mensajeExito = ref("");

// perfil.barberia viene unido en la consulta de obtenerMiPerfil()
const barberia = computed(() => perfil.value?.barberia ?? null);

// El link propio de cada barbería: /reservar/<slug>
const linkReserva = computed(() =>
  barberia.value ? `${window.location.origin}/reservar/${barberia.value.slug}` : ""
);

const turnosActivos = computed(
  () => turnos.value.filter((t) => t.estado !== "cancelado").length
);

// LECTURA: trae los turnos del día elegido, ordenados por hora
async function cargarTurnos() {
  if (!barberia.value || !fecha.value) return;

  cargando.value = true;
  error.value = "";

  const { data, error: err } = await listarTurnosDelDia(barberia.value.id, fecha.value);

  cargando.value = false;

  if (err) {
    error.value = "No se pudieron cargar los turnos.";
    return;
  }

  turnos.value = data;
}

onMounted(async () => {
  const { data, error: err } = await obtenerMiPerfil();

  if (err || !data) {
    cargando.value = false;
    error.value =
      "Tu usuario no tiene una barbería asociada. Creá una cuenta nueva desde «Registrarme».";
    return;
  }

  perfil.value = data;
  cargarTurnos();
});

// Cada vez que cambio la fecha, recargo la agenda
watch(fecha, cargarTurnos);

function iniciales(nombre = "") {
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

// TurnoForm me manda el mensaje ("Turno creado.", "Turno eliminado.", etc.)
let temporizador = null;
function alGuardar(mensaje) {
  cerrarForm();
  cargarTurnos();

  mensajeExito.value = mensaje;
  clearTimeout(temporizador);
  temporizador = setTimeout(() => (mensajeExito.value = ""), 3000);
}

async function copiarLink() {
  try {
    await navigator.clipboard.writeText(linkReserva.value);
    linkCopiado.value = true;
    setTimeout(() => (linkCopiado.value = false), 2500);
  } catch {
    // Si el navegador no deja copiar, el link igual está a la vista
  }
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Agenda</h2>
      <p>{{ barberia?.nombre || "Mi barbería" }}</p>
    </div>

    <div v-if="barberia" class="card link-card">
      <div>
        <strong>Tu link de reservas</strong>
        <div class="muted link-texto">{{ linkReserva }}</div>
      </div>
      <div class="acciones">
        <button class="btn btn-secondary" @click="copiarLink">
          {{ linkCopiado ? "¡Copiado!" : "Copiar" }}
        </button>
        <a class="btn btn-secondary" :href="linkReserva" target="_blank">Ver mi página</a>
      </div>
    </div>

    <div v-if="barberia" class="card">
      <div class="form-group" style="margin-bottom: 14px;">
        <label>Día</label>
        <input v-model="fecha" type="date" />
      </div>

      <div class="card-header">
        <div>
          <strong>
            {{ turnosActivos }} {{ turnosActivos === 1 ? "turno activo" : "turnos activos" }}
          </strong>
          <div class="muted">Tocá un turno para editarlo</div>
        </div>
        <button class="btn btn-primary" @click="abrirAlta">+ Nuevo turno</button>
      </div>
    </div>

    <p v-if="mensajeExito" class="exito-text center-text">✓ {{ mensajeExito }}</p>

    <p v-if="error" class="error-text center-text">{{ error }}</p>
    <p v-else-if="cargando" class="muted center-text">Cargando turnos...</p>

    <div v-else-if="turnos.length === 0" class="card turno-libre center-text">
      <p class="muted" style="margin: 6px 0;">No hay turnos para este día.</p>
    </div>

    <template v-else>
      <div
        v-for="turno in turnos"
        :key="turno.id"
        class="card turno-card"
        :class="{ 'turno-cancelado': turno.estado === 'cancelado' }"
        @click="abrirEdicion(turno)"
      >
        <div class="timeline-item">
          <div class="timeline-hora">{{ horaCorta(turno.hora) }}</div>

          <div class="avatar">{{ iniciales(turno.cliente?.nombre) }}</div>

          <div class="turno-info">
            <strong>{{ turno.cliente?.nombre }}</strong>
            <div class="muted">
              {{ turno.servicio?.nombre }} · {{ turno.barbero?.nombre }}
            </div>
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
      :barberia-id="barberia.id"
      :perfil-id="perfil.id"
      @cerrar="cerrarForm"
      @guardado="alGuardar"
    />
  </div>
</template>

<style scoped>
.link-card {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.link-texto {
  word-break: break-all;
  margin-top: 2px;
}

.acciones {
  display: flex;
  gap: 8px;
}

.acciones a {
  text-decoration: none;
}

.turno-cancelado {
  opacity: 0.55;
}
</style>
