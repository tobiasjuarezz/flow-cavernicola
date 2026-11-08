<script setup>
import { ref, reactive, computed, onMounted } from "vue";
import { obtenerMiPerfil, listarServicios, guardarServicio } from "@/services/db";
import { precio } from "@/utils/fechas";
import { normalizar } from "@/utils/buscar";
import ServicioForm from "@/components/ServicioForm.vue";

// Esta pantalla es solo para el dueño: el router no deja entrar a otro
// rol y, aunque alguien entrara igual, la base (RLS) no lo deja guardar.

const barberia = ref(null);
const servicios = ref([]);
const cargando = ref(true);
const error = ref("");
const mensajeExito = ref("");

const formAbierto = ref(false);
const servicioEditando = ref(null);

const filtros = reactive({ texto: "", orden: "nombre" });

async function cargarServicios() {
  cargando.value = true;
  const { data, error: err } = await listarServicios(barberia.value.id);
  cargando.value = false;

  if (err) {
    error.value = "No se pudieron cargar los servicios.";
    return;
  }
  servicios.value = data;
}

onMounted(async () => {
  const { data } = await obtenerMiPerfil();
  if (!data) {
    cargando.value = false;
    error.value = "Tu usuario no tiene una barbería asociada.";
    return;
  }
  barberia.value = data.barberia;
  cargarServicios();
});

// Búsqueda por nombre y orden
const serviciosVisibles = computed(() => {
  const texto = normalizar(filtros.texto);
  const lista = servicios.value.filter((s) => !texto || normalizar(s.nombre).includes(texto));

  return [...lista].sort((a, b) => {
    if (filtros.orden === "precio") return a.precio - b.precio;
    if (filtros.orden === "duracion") return a.duracion_min - b.duracion_min;
    return a.nombre.localeCompare(b.nombre, "es");
  });
});

let temporizador = null;
function avisar(mensaje) {
  mensajeExito.value = mensaje;
  clearTimeout(temporizador);
  temporizador = setTimeout(() => (mensajeExito.value = ""), 3000);
}

function abrirAlta() {
  servicioEditando.value = null;
  formAbierto.value = true;
}

function abrirEdicion(servicio) {
  servicioEditando.value = servicio;
  formAbierto.value = true;
}

function alGuardar(mensaje) {
  formAbierto.value = false;
  servicioEditando.value = null;
  cargarServicios();
  avisar(mensaje);
}

// Activar / desactivar sin abrir el formulario
async function cambiarActivo(servicio) {
  error.value = "";
  const { error: err } = await guardarServicio({
    id: servicio.id,
    barberia_id: barberia.value.id,
    activo: !servicio.activo,
  });
  if (err) {
    error.value = "No se pudo cambiar el servicio.";
    return;
  }
  cargarServicios();
  avisar(servicio.activo ? "Servicio desactivado." : "Servicio activado.");
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Servicios</h2>
      <p>Lo que ofrece {{ barberia?.nombre || "tu barbería" }} y cuánto cobra</p>
    </div>

    <div class="card">
      <div class="fila">
        <div class="form-group">
          <label>Buscar</label>
          <input v-model="filtros.texto" type="search" placeholder="Nombre del servicio" />
        </div>
        <div class="form-group">
          <label>Ordenar por</label>
          <select v-model="filtros.orden">
            <option value="nombre">Nombre (A-Z)</option>
            <option value="precio">Precio</option>
            <option value="duracion">Duración</option>
          </select>
        </div>
      </div>

      <div class="card-header">
        <div>
          <strong>{{ serviciosVisibles.length }} servicios</strong>
          <div class="muted">Los inactivos no aparecen en tu página de reservas</div>
        </div>
        <button class="btn btn-primary" @click="abrirAlta">+ Nuevo servicio</button>
      </div>
    </div>

    <p v-if="mensajeExito" class="exito-text center-text">✓ {{ mensajeExito }}</p>
    <p v-if="error" class="error-text center-text">{{ error }}</p>

    <p v-if="cargando" class="muted center-text">Cargando servicios...</p>

    <div v-else-if="serviciosVisibles.length === 0" class="card turno-libre center-text">
      <p class="muted" style="margin: 6px 0;">No hay servicios que coincidan con la búsqueda.</p>
    </div>

    <div
      v-for="s in serviciosVisibles"
      v-else
      :key="s.id"
      class="card servicio-card"
      :class="{ inactivo: !s.activo }"
    >
      <div class="servicio-info">
        <strong>{{ s.nombre }}</strong>
        <div class="muted">{{ s.duracion_min }} min · {{ precio(s.precio) }}</div>
      </div>
      <span class="badge" :class="s.activo ? 'badge-completado' : 'badge-cancelado'">
        {{ s.activo ? "Activo" : "Inactivo" }}
      </span>
      <div class="servicio-acciones">
        <button class="btn btn-secondary" @click="abrirEdicion(s)">Editar</button>
        <button class="btn btn-secondary" @click="cambiarActivo(s)">
          {{ s.activo ? "Desactivar" : "Activar" }}
        </button>
      </div>
    </div>

    <ServicioForm
      v-if="formAbierto"
      :servicio="servicioEditando"
      :barberia-id="barberia.id"
      @cerrar="formAbierto = false"
      @guardado="alGuardar"
    />
  </div>
</template>

<style scoped>
.fila {
  display: flex;
  gap: 10px;
}

.fila .form-group {
  flex: 1;
  min-width: 0;
}

.servicio-card {
  display: flex;
  align-items: center;
  gap: 12px;
  flex-wrap: wrap;
}

.servicio-info {
  flex: 1;
  min-width: 140px;
}

.servicio-acciones {
  display: flex;
  gap: 8px;
  width: 100%;
}

.servicio-acciones .btn {
  padding: 8px 14px;
  font-size: 12.5px;
}

.inactivo .servicio-info {
  opacity: 0.55;
}
</style>
