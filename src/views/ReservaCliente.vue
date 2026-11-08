<script setup>
import { ref, computed, onMounted, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import {
  buscarBarberiaPorSlug,
  listarServicios,
  horariosDisponibles,
  reservarTurno,
} from "@/services/db";
import { hoy, sumarDias, fechaCorta, precio } from "@/utils/fechas";
import { validarNombre, validarTelefono } from "@/utils/validaciones";

const route = useRoute();
const router = useRouter();

// El slug viene del link: /reservar/la-cueva-barber
const slug = route.params.slug;

const barberia = ref(null);
const servicios = ref([]);
const cargando = ref(true);
const noExiste = ref(false);

const servicioId = ref(null);
const fecha = ref(hoy());
const horas = ref([]);
const cargandoHoras = ref(false);
const horaElegida = ref(null);

const nombre = ref("");
const telefono = ref("");
const error = ref("");
const enviando = ref(false);

// Los próximos 14 días para elegir
const dias = computed(() =>
  Array.from({ length: 14 }, (_, i) => {
    const f = sumarDias(hoy(), i);
    const etiqueta = i === 0 ? "Hoy" : i === 1 ? "Mañana" : fechaCorta(f);
    return { fecha: f, etiqueta };
  })
);

onMounted(async () => {
  const { data, error: err } = await buscarBarberiaPorSlug(slug);

  if (err || !data) {
    noExiste.value = true;
    cargando.value = false;
    return;
  }

  barberia.value = data;

  const resp = await listarServicios(data.id);
  servicios.value = (resp.data ?? []).filter((s) => s.activo);
  servicioId.value = servicios.value[0]?.id ?? null;

  cargando.value = false;
  cargarHoras();
});

// Cada vez que cambia el día, busco las horas libres de nuevo
watch(fecha, () => {
  horaElegida.value = null;
  cargarHoras();
});

async function cargarHoras() {
  cargandoHoras.value = true;
  const { data } = await horariosDisponibles(slug, fecha.value);
  horas.value = data ?? [];
  cargandoHoras.value = false;
}

// Los errores que escribí yo en reservar_turno() ya vienen en castellano;
// cualquier otro (por ej. sin internet) lo reemplazo por uno genérico
function traducirError(err) {
  if (err.code === "23505" || err.message?.includes("ya no está disponible")) {
    return "Ese horario se acaba de ocupar. Elegí otro.";
  }
  const propios = ["Completá", "Esa barbería", "Ese servicio", "Ese horario"];
  if (propios.some((p) => err.message?.startsWith(p))) return err.message;
  return "No se pudo reservar. Probá de nuevo.";
}

async function confirmarReserva() {
  error.value = "";

  if (!servicioId.value) {
    error.value = "Elegí un servicio.";
    return;
  }
  if (!horaElegida.value) {
    error.value = "Elegí un horario disponible.";
    return;
  }
  // Valido el formato antes de mandar nada a la base
  const errorDatos = validarNombre(nombre.value) || validarTelefono(telefono.value);
  if (errorDatos) {
    error.value = errorDatos;
    return;
  }

  enviando.value = true;

  const { data, error: err } = await reservarTurno({
    slug,
    servicioId: servicioId.value,
    fecha: fecha.value,
    hora: horaElegida.value,
    nombre: nombre.value.trim(),
    telefono: telefono.value.trim(),
  });

  enviando.value = false;

  if (err) {
    error.value = traducirError(err);
    horaElegida.value = null;
    cargarHoras(); // refresco por si alguien me ganó el horario
    return;
  }

  router.push({
    name: "confirmacion",
    query: {
      slug,
      barberia: data.barberia,
      servicio: data.servicio,
      fecha: data.fecha,
      hora: data.hora,
      nombre: nombre.value.trim(),
    },
  });
}
</script>

<template>
  <div class="container">
    <p v-if="cargando" class="muted center-text">Cargando...</p>

    <div v-else-if="noExiste" class="card center-text">
      <h2 class="titulo-chico">Barbería no encontrada</h2>
      <p class="muted">Revisá que el link esté bien escrito o pedíselo de nuevo a tu barbería.</p>
    </div>

    <template v-else>
      <div class="page-title">
        <h2>Reservá tu turno</h2>
        <p>
          {{ barberia.nombre }}
          <span v-if="barberia.direccion"> · {{ barberia.direccion }}</span>
        </p>
      </div>

      <div class="card">
        <strong>1. ¿Qué te vas a hacer?</strong>
        <div class="lista-servicios">
          <div
            v-for="s in servicios"
            :key="s.id"
            class="opcion-servicio"
            :class="{ selected: servicioId === s.id }"
            @click="servicioId = s.id"
          >
            <span>{{ s.nombre }}</span>
            <span class="muted">{{ s.duracion_min }} min · {{ precio(s.precio) }}</span>
          </div>
        </div>
        <p v-if="servicios.length === 0" class="muted">Esta barbería todavía no cargó servicios.</p>
      </div>

      <div class="card">
        <strong>2. Elegí el día</strong>
        <div class="dias-scroll">
          <div
            v-for="d in dias"
            :key="d.fecha"
            class="slot dia"
            :class="{ selected: fecha === d.fecha }"
            @click="fecha = d.fecha"
          >
            {{ d.etiqueta }}
          </div>
        </div>

        <strong style="display: block; margin-top: 18px;">3. Elegí la hora</strong>
        <p v-if="cargandoHoras" class="muted">Buscando horarios...</p>
        <p v-else-if="horas.length === 0" class="muted">
          No quedan horarios libres ese día. Probá con otro.
        </p>
        <div v-else class="slots-grid">
          <div
            v-for="h in horas"
            :key="h"
            class="slot"
            :class="{ selected: horaElegida === h }"
            @click="horaElegida = h"
          >
            {{ h }}
          </div>
        </div>
      </div>

      <form class="card" novalidate @submit.prevent="confirmarReserva">
        <strong style="display: block; margin-bottom: 14px;">4. Tus datos</strong>
        <div class="form-group">
          <label>Nombre</label>
          <input v-model="nombre" type="text" placeholder="Tu nombre" />
        </div>
        <div class="form-group">
          <label>Teléfono (WhatsApp)</label>
          <input v-model="telefono" type="tel" placeholder="11 1234-5678" />
        </div>

        <p v-if="error" class="error-text">{{ error }}</p>

        <button class="btn btn-primary btn-block" type="submit" :disabled="enviando">
          {{ enviando ? "Reservando..." : "Confirmar turno" }}
        </button>
      </form>
    </template>
  </div>
</template>

<style scoped>
.titulo-chico {
  font-family: "Bebas Neue", sans-serif;
  font-size: 26px;
  margin: 6px 0 8px;
}

.lista-servicios {
  display: flex;
  flex-direction: column;
  gap: 8px;
  margin-top: 12px;
}

.opcion-servicio {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 10px;
  border: 1.5px solid var(--borde);
  border-radius: 10px;
  padding: 12px 14px;
  cursor: pointer;
  font-weight: 600;
  font-size: 14px;
  transition: all 0.15s ease;
}

.opcion-servicio:hover {
  border-color: var(--mostaza);
  background: #fff8ea;
}

.opcion-servicio.selected {
  background: var(--negro);
  color: var(--mostaza-suave);
  border-color: var(--negro);
}

.opcion-servicio.selected .muted {
  color: var(--mostaza-suave);
}

.dias-scroll {
  display: flex;
  gap: 8px;
  overflow-x: auto;
  margin-top: 12px;
  padding-bottom: 4px;
}

.dia {
  flex-shrink: 0;
  min-width: 78px;
  text-transform: capitalize;
}
</style>
