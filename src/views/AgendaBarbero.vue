<script setup>
import { ref, reactive, computed, onMounted, watch } from "vue";
import { useRoute } from "vue-router";
import { obtenerMiPerfil, listarTurnos } from "@/services/db";
import { hoy, sumarDias, horaCorta, fechaCorta } from "@/utils/fechas";
import { normalizar, soloDigitos } from "@/utils/buscar";
import TurnoForm from "@/components/TurnoForm.vue";

const route = useRoute();

const perfil = ref(null);
const turnos = ref([]); // lo que trajo la base (ya filtrado por fecha y estado)
const cargando = ref(true);
const error = ref("");

const formAbierto = ref(false);
const turnoEditando = ref(null);
const linkCopiado = ref(false);
const mensajeExito = ref("");

// Si el router me mandó acá porque quiso entrar a algo sin permiso
const aviso = ref(
  route.query.aviso === "sin-permiso" ? "No tenés permiso para entrar a esa sección." : ""
);

// Búsqueda, filtros y orden
const filtros = reactive({
  periodo: "dia", // "dia" | "semana" | "todos"
  fecha: hoy(),
  estado: "", // "" = todos
  texto: "", // nombre o teléfono del cliente
  orden: "hora", // "hora" | "cliente" | "estado"
});

// perfil.barberia viene unido en la consulta de obtenerMiPerfil()
const barberia = computed(() => perfil.value?.barberia ?? null);
const esDueno = computed(() => perfil.value?.rol === "dueno");

// El link propio de cada barbería: /reservar/<slug>
const linkReserva = computed(() =>
  barberia.value ? `${window.location.origin}/reservar/${barberia.value.slug}` : ""
);

// ---------------------------------------------------------------------
// CONSULTA a la base: trae los turnos del período y estado elegidos
// ---------------------------------------------------------------------
function rangoDeFechas() {
  if (filtros.periodo === "dia") return { desde: filtros.fecha, hasta: filtros.fecha };
  if (filtros.periodo === "semana") return { desde: hoy(), hasta: sumarDias(hoy(), 6) };
  return {}; // "todos": sin límite de fechas
}

async function cargarTurnos() {
  if (!barberia.value) return;
  if (filtros.periodo === "dia" && !filtros.fecha) return;

  cargando.value = true;
  error.value = "";

  const { data, error: err } = await listarTurnos(barberia.value.id, {
    ...rangoDeFechas(),
    estado: filtros.estado,
  });

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

// Si cambia el período, el día o el estado, vuelvo a pedir a la base
watch(() => [filtros.periodo, filtros.fecha, filtros.estado], cargarTurnos);

// ---------------------------------------------------------------------
// BÚSQUEDA y ORDEN: sobre lo que ya trajo la base
// ---------------------------------------------------------------------
const ORDEN_ESTADO = { pendiente: 1, confirmado: 2, completado: 3, cancelado: 4 };

const turnosVisibles = computed(() => {
  const texto = normalizar(filtros.texto);
  const digitos = soloDigitos(filtros.texto);

  // Busco por nombre del cliente o por su teléfono
  const encontrados = turnos.value.filter((t) => {
    if (!texto) return true;
    const nombre = normalizar(t.cliente?.nombre);
    const telefono = soloDigitos(t.cliente?.telefono);
    return nombre.includes(texto) || (digitos.length >= 3 && telefono.includes(digitos));
  });

  const porFechaYHora = (a, b) => (a.fecha + a.hora).localeCompare(b.fecha + b.hora);

  return [...encontrados].sort((a, b) => {
    if (filtros.orden === "cliente") {
      return (
        (a.cliente?.nombre ?? "").localeCompare(b.cliente?.nombre ?? "", "es") ||
        porFechaYHora(a, b)
      );
    }
    if (filtros.orden === "estado") {
      return ORDEN_ESTADO[a.estado] - ORDEN_ESTADO[b.estado] || porFechaYHora(a, b);
    }
    return porFechaYHora(a, b);
  });
});

const turnosActivos = computed(
  () => turnosVisibles.value.filter((t) => t.estado !== "cancelado").length
);

const hayBusqueda = computed(() => !!(filtros.estado || filtros.texto.trim()));

function limpiarBusqueda() {
  filtros.estado = "";
  filtros.texto = "";
}

// ---------------------------------------------------------------------
// ALTA, EDICIÓN y BAJA (con el formulario)
// ---------------------------------------------------------------------

// El dueño edita cualquier turno; el barbero, solo los suyos.
// (Esto es para la pantalla: la base lo vuelve a controlar con RLS)
function puedeEditar(turno) {
  return esDueno.value || turno.barbero?.id === perfil.value?.id;
}

let temporizadorAviso = null;
function mostrarAviso(texto) {
  aviso.value = texto;
  clearTimeout(temporizadorAviso);
  temporizadorAviso = setTimeout(() => (aviso.value = ""), 4000);
}

function abrirAlta() {
  turnoEditando.value = null;
  formAbierto.value = true;
}

function abrirEdicion(turno) {
  if (!puedeEditar(turno)) {
    mostrarAviso("Solo podés modificar tus propios turnos.");
    return;
  }
  turnoEditando.value = turno;
  formAbierto.value = true;
}

function cerrarForm() {
  formAbierto.value = false;
  turnoEditando.value = null;
}

// TurnoForm me manda el mensaje ("Turno creado.", "Turno eliminado.", etc.)
let temporizadorExito = null;
function alGuardar(mensaje) {
  cerrarForm();
  cargarTurnos();

  mensajeExito.value = mensaje;
  clearTimeout(temporizadorExito);
  temporizadorExito = setTimeout(() => (mensajeExito.value = ""), 3000);
}

function iniciales(nombre = "") {
  return nombre
    .split(" ")
    .filter(Boolean)
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();
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
      <p>
        {{ barberia?.nombre || "Mi barbería" }}
        <span v-if="perfil"> · {{ esDueno ? "Dueño" : "Barbero" }}</span>
      </p>
    </div>

    <p v-if="aviso" class="aviso-text">{{ aviso }}</p>

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
      <div class="fila">
        <div class="form-group">
          <label>Mostrar</label>
          <select v-model="filtros.periodo">
            <option value="dia">Un día</option>
            <option value="semana">Próximos 7 días</option>
            <option value="todos">Todos</option>
          </select>
        </div>
        <div v-if="filtros.periodo === 'dia'" class="form-group">
          <label>Día</label>
          <input v-model="filtros.fecha" type="date" />
        </div>
      </div>

      <div class="form-group">
        <label>Buscar cliente</label>
        <input v-model="filtros.texto" type="search" placeholder="Nombre o teléfono" />
      </div>

      <div class="fila">
        <div class="form-group">
          <label>Estado</label>
          <select v-model="filtros.estado">
            <option value="">Todos</option>
            <option value="pendiente">Pendiente</option>
            <option value="confirmado">Confirmado</option>
            <option value="completado">Completado</option>
            <option value="cancelado">Cancelado</option>
          </select>
        </div>
        <div class="form-group">
          <label>Ordenar por</label>
          <select v-model="filtros.orden">
            <option value="hora">Fecha y hora</option>
            <option value="cliente">Cliente (A-Z)</option>
            <option value="estado">Estado</option>
          </select>
        </div>
      </div>

      <div class="card-header">
        <div>
          <strong>
            {{ turnosActivos }} {{ turnosActivos === 1 ? "turno activo" : "turnos activos" }}
          </strong>
          <div class="muted">
            <a v-if="hayBusqueda" href="#" @click.prevent="limpiarBusqueda">Limpiar búsqueda</a>
            <span v-else>Tocá un turno para editarlo</span>
          </div>
        </div>
        <button class="btn btn-primary" @click="abrirAlta">+ Nuevo turno</button>
      </div>
    </div>

    <p v-if="mensajeExito" class="exito-text center-text">✓ {{ mensajeExito }}</p>

    <p v-if="error" class="error-text center-text">{{ error }}</p>
    <p v-else-if="cargando" class="muted center-text">Cargando turnos...</p>

    <div v-else-if="turnosVisibles.length === 0" class="card turno-libre center-text">
      <p class="muted" style="margin: 6px 0;">
        {{ hayBusqueda ? "No hay turnos que coincidan con la búsqueda." : "No hay turnos para este período." }}
      </p>
    </div>

    <template v-else>
      <div
        v-for="turno in turnosVisibles"
        :key="turno.id"
        class="card turno-card"
        :class="{
          'turno-cancelado': turno.estado === 'cancelado',
          'turno-ajeno': !puedeEditar(turno),
        }"
        @click="abrirEdicion(turno)"
      >
        <div class="timeline-item">
          <div class="timeline-hora">
            <div v-if="filtros.periodo !== 'dia'" class="fecha-chica">{{ fechaCorta(turno.fecha) }}</div>
            {{ horaCorta(turno.hora) }}
          </div>

          <div class="avatar">{{ iniciales(turno.cliente?.nombre) }}</div>

          <div class="turno-info">
            <strong>{{ turno.cliente?.nombre }}</strong>
            <div class="muted">{{ turno.servicio?.nombre }} · {{ turno.barbero?.nombre }}</div>
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
      :fecha-inicial="filtros.periodo === 'dia' ? filtros.fecha : hoy()"
      :barberia-id="barberia.id"
      :perfil-id="perfil.id"
      :rol="perfil.rol"
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

.fila {
  display: flex;
  gap: 10px;
}

.fila .form-group {
  flex: 1;
  min-width: 0;
}

.fecha-chica {
  font-family: "Poppins", sans-serif;
  font-size: 11px;
  font-weight: 600;
  color: var(--texto-muted);
  text-transform: capitalize;
  letter-spacing: 0;
}

.turno-cancelado {
  opacity: 0.55;
}

/* Turnos de otro barbero: se ven, pero no se pueden editar */
.turno-ajeno,
.turno-ajeno .timeline-item {
  cursor: default;
}

.card.turno-card.turno-ajeno:hover {
  transform: none;
  box-shadow: var(--sombra);
  border-color: var(--borde);
}
</style>
