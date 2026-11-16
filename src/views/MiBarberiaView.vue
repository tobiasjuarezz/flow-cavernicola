<script setup>
import { ref, reactive, computed, onMounted, watch } from "vue";
import {
  obtenerMiPerfil,
  obtenerMiBarberia,
  guardarBarberia,
  listarBarberos,
  listarHorarios,
  guardarHorario,
  eliminarHorario,
} from "@/services/db";
import { validarBarberia, validarHorario } from "@/utils/validaciones";

// Pantalla solo para el dueño: el router no deja entrar a otro rol y,
// aunque alguien entrara igual, la base (RLS) no lo deja guardar.

// Para mostrar los días. En la base: 0 = domingo, 1 = lunes ... 6 = sábado
const DIAS = ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"];
// Orden en que los muestro: de lunes a domingo
const ORDEN_DIAS = [1, 2, 3, 4, 5, 6, 0];

const perfil = ref(null);
const cargando = ref(true);
const errorGeneral = ref("");

// ---------------------------------------------------------------------
// DATOS DE LA BARBERÍA
// ---------------------------------------------------------------------
const barberia = ref(null); // lo que está guardado en la base
const datos = reactive({ nombre: "", telefono: "", direccion: "" }); // lo que se edita
const errorDatos = ref("");
const exitoDatos = ref("");
const guardandoDatos = ref(false);
const linkCopiado = ref(false);

const linkReserva = computed(() =>
  barberia.value ? `${window.location.origin}/reservar/${barberia.value.slug}` : ""
);

async function cargarBarberia() {
  const { data, error } = await obtenerMiBarberia(perfil.value.barberia.id);
  if (error) {
    errorGeneral.value = "No se pudieron cargar los datos de tu barbería.";
    return;
  }
  barberia.value = data;
  datos.nombre = data.nombre ?? "";
  datos.telefono = data.telefono ?? "";
  datos.direccion = data.direccion ?? "";
}

async function guardarDatos() {
  errorDatos.value = "";
  exitoDatos.value = "";

  const problema = validarBarberia(datos);
  if (problema) {
    errorDatos.value = problema;
    return;
  }

  guardandoDatos.value = true;
  const { error } = await guardarBarberia({
    id: barberia.value.id,
    nombre: datos.nombre.trim(),
    // vacío se guarda como null (el dato es opcional)
    telefono: datos.telefono.trim() || null,
    direccion: datos.direccion.trim() || null,
  });
  guardandoDatos.value = false;

  if (error) {
    errorDatos.value =
      error.code === "SIN_PERMISO" || error.code === "42501"
        ? "No tenés permiso para hacer eso."
        : "No se pudieron guardar los datos. Probá de nuevo.";
    return;
  }

  await cargarBarberia();
  exitoDatos.value = "Datos guardados.";
  setTimeout(() => (exitoDatos.value = ""), 3000);
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

// ---------------------------------------------------------------------
// HORARIOS DE ATENCIÓN
// ---------------------------------------------------------------------
const barberos = ref([]);
const barberoElegido = ref(""); // id del perfil cuyos horarios se ven
const horarios = ref([]); // lo que está guardado en la base (de todos los barberos)
const filas = ref([]); // copia editable de las franjas del barbero elegido
const exitoHorarios = ref("");

// "10:00:00" -> "10:00" (el input type="time" usa HH:MM)
const corta = (hora) => (hora ? hora.slice(0, 5) : "");

const ordenDia = (dia) => ORDEN_DIAS.indexOf(Number(dia));

// Paso lo guardado a filas editables. Cada fila recuerda cómo estaba
// ("original") para saber si se modificó y mostrar el botón Guardar.
function armarFilas() {
  filas.value = horarios.value
    .filter((h) => h.perfil_id === barberoElegido.value)
    .map((h) => {
      const fila = {
        id: h.id,
        dia_semana: Number(h.dia_semana),
        hora_inicio: corta(h.hora_inicio),
        hora_fin: corta(h.hora_fin),
      };
      return { ...fila, original: { ...fila }, nueva: false, confirmando: false, error: "" };
    })
    .sort((a, b) => ordenDia(a.dia_semana) - ordenDia(b.dia_semana) || a.hora_inicio.localeCompare(b.hora_inicio));
}

async function cargarHorarios() {
  const { data, error } = await listarHorarios(perfil.value.barberia.id);
  if (error) {
    errorGeneral.value = "No se pudieron cargar los horarios.";
    return;
  }
  horarios.value = data;
  armarFilas();
}

// Al cambiar de barbero en el selector, muestro sus franjas
watch(barberoElegido, armarFilas);

// Resumen arriba de la lista: "Trabaja: Mar, Mié, Jue, Vie y Sáb."
// Uso "original" para mostrar lo que está GUARDADO, no lo que se está editando
const resumen = computed(() => {
  const dias = [...new Set(filas.value.filter((f) => !f.nueva).map((f) => f.original.dia_semana))]
    .sort((a, b) => ordenDia(a) - ordenDia(b))
    .map((d) => DIAS[d].slice(0, 3));
  if (dias.length === 0) return "No tiene horarios: no aparece en la página de reservas.";
  if (dias.length === 1) return `Trabaja: ${dias[0]}.`;
  return `Trabaja: ${dias.slice(0, -1).join(", ")} y ${dias[dias.length - 1]}.`;
});

function seModifico(fila) {
  return (
    fila.nueva ||
    fila.dia_semana !== fila.original.dia_semana ||
    fila.hora_inicio !== fila.original.hora_inicio ||
    fila.hora_fin !== fila.original.hora_fin
  );
}

function avisarHorarios(mensaje) {
  exitoHorarios.value = mensaje;
  setTimeout(() => (exitoHorarios.value = ""), 3000);
}

// ALTA: agrego una fila vacía que recién se guarda al tocar "Guardar"
function agregarFila() {
  filas.value.push({
    id: null,
    dia_semana: 1,
    hora_inicio: "10:00",
    hora_fin: "20:00",
    original: null,
    nueva: true,
    confirmando: false,
    error: "",
  });
}

function traducirErrorHorario(err) {
  // 23P01 = el trigger horarios_sin_superponer de la base
  if (err.code === "23P01") return "Esa franja se superpone con otra del mismo barbero ese día.";
  // 23514 = check (hora_fin > hora_inicio) de la tabla
  if (err.code === "23514") return "La hora de fin tiene que ser después de la de inicio.";
  if (err.code === "SIN_PERMISO" || err.code === "42501") return "No tenés permiso para hacer eso.";
  return "No se pudo guardar el horario. Probá de nuevo.";
}

// ALTA y MODIFICACIÓN: las dos pasan por las mismas reglas
async function guardarFila(fila) {
  fila.error = "";

  // Las demás franjas guardadas de este barbero (sin la que estoy editando)
  const otras = horarios.value.filter((h) => h.perfil_id === barberoElegido.value && h.id !== fila.id);
  const problema = validarHorario(fila, otras);
  if (problema) {
    fila.error = problema;
    return;
  }

  const horario = {
    barberia_id: perfil.value.barberia.id,
    perfil_id: barberoElegido.value,
    dia_semana: Number(fila.dia_semana),
    hora_inicio: fila.hora_inicio,
    hora_fin: fila.hora_fin,
  };
  if (!fila.nueva) horario.id = fila.id;

  const { error } = await guardarHorario(horario);
  if (error) {
    fila.error = traducirErrorHorario(error);
    return;
  }

  const mensaje = fila.nueva ? "Franja agregada." : "Horario actualizado.";
  await cargarHorarios();
  avisarHorarios(mensaje);
}

// BAJA: si la fila es nueva solo la saco; si no, pido confirmación
function pedirEliminar(fila) {
  if (fila.nueva) {
    filas.value = filas.value.filter((f) => f !== fila);
    return;
  }
  fila.confirmando = true;
}

async function eliminarFila(fila) {
  fila.error = "";
  const { error } = await eliminarHorario(fila.id);
  fila.confirmando = false;

  if (error) {
    fila.error = traducirErrorHorario(error);
    return;
  }

  await cargarHorarios();
  avisarHorarios("Franja eliminada.");
}

// ---------------------------------------------------------------------
// CARGA INICIAL
// ---------------------------------------------------------------------
onMounted(async () => {
  const { data } = await obtenerMiPerfil();
  if (!data) {
    cargando.value = false;
    errorGeneral.value = "Tu usuario no tiene una barbería asociada.";
    return;
  }
  perfil.value = data;

  const { data: lista } = await listarBarberos(data.barberia.id);
  barberos.value = lista ?? [];
  barberoElegido.value = data.id; // arranco mostrando los horarios del dueño

  await Promise.all([cargarBarberia(), cargarHorarios()]);
  cargando.value = false;
});
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Mi barbería</h2>
      <p>Los datos que ven tus clientes y los horarios de atención</p>
    </div>

    <p v-if="errorGeneral" class="error-text center-text">{{ errorGeneral }}</p>
    <p v-if="cargando" class="muted center-text">Cargando...</p>

    <template v-else-if="barberia">
      <!-- ============ DATOS DE LA BARBERÍA ============ -->
      <form class="card" novalidate @submit.prevent="guardarDatos">
        <div class="card-header" style="margin-bottom: 14px;">
          <strong>Datos de la barbería</strong>
          <span class="badge badge-confirmado">Plan {{ barberia.plan }}</span>
        </div>

        <div class="form-group">
          <label>Nombre</label>
          <input v-model="datos.nombre" type="text" maxlength="60" placeholder="Ej: La Cueva Barber" />
        </div>

        <div class="fila">
          <div class="form-group">
            <label>Teléfono (opcional)</label>
            <input v-model="datos.telefono" type="tel" placeholder="11 5555-1010" />
          </div>
          <div class="form-group">
            <label>Dirección (opcional)</label>
            <input v-model="datos.direccion" type="text" maxlength="100" placeholder="Av. Alem 345" />
          </div>
        </div>

        <div class="form-group">
          <label>Tu link de reservas</label>
          <div class="link-fila">
            <input :value="linkReserva" type="text" readonly />
            <button class="btn btn-secondary" type="button" @click="copiarLink">
              {{ linkCopiado ? "¡Copiado!" : "Copiar" }}
            </button>
          </div>
          <div class="muted ayuda">El link no cambia aunque cambies el nombre, así no se rompe el que ya compartiste.</div>
        </div>

        <p v-if="errorDatos" class="error-text">{{ errorDatos }}</p>
        <p v-if="exitoDatos" class="exito-text">✓ {{ exitoDatos }}</p>

        <button class="btn btn-primary" type="submit" :disabled="guardandoDatos">
          {{ guardandoDatos ? "Guardando..." : "Guardar datos" }}
        </button>
      </form>

      <!-- ============ HORARIOS DE ATENCIÓN ============ -->
      <div class="card">
        <div class="card-header" style="margin-bottom: 10px;">
          <div>
            <strong>Horarios de atención</strong>
            <div class="muted">{{ resumen }}</div>
          </div>
        </div>

        <div v-if="barberos.length > 1" class="form-group">
          <label>Barbero</label>
          <select v-model="barberoElegido">
            <option v-for="b in barberos" :key="b.id" :value="b.id">{{ b.nombre }}</option>
          </select>
        </div>

        <p v-if="filas.length === 0" class="muted center-text" style="margin: 14px 0;">
          Todavía no cargaste ninguna franja.
        </p>

        <div v-for="(fila, i) in filas" :key="fila.id ?? 'nueva-' + i" class="franja">
          <div class="franja-campos">
            <div class="form-group">
              <label>Día</label>
              <select v-model.number="fila.dia_semana">
                <option v-for="d in ORDEN_DIAS" :key="d" :value="d">{{ DIAS[d] }}</option>
              </select>
            </div>
            <div class="form-group">
              <label>Desde</label>
              <input v-model="fila.hora_inicio" type="time" step="1800" />
            </div>
            <div class="form-group">
              <label>Hasta</label>
              <input v-model="fila.hora_fin" type="time" step="1800" />
            </div>
          </div>

          <p v-if="fila.error" class="error-text">{{ fila.error }}</p>

          <!-- Confirmación antes de eliminar -->
          <div v-if="fila.confirmando" class="confirmar-borrado">
            <p>
              ¿Seguro que querés eliminar el horario del <strong>{{ DIAS[fila.original.dia_semana] }}</strong>
              de {{ fila.original.hora_inicio }} a {{ fila.original.hora_fin }}?
              Los turnos ya reservados no se borran.
            </p>
            <div style="display: flex; gap: 8px;">
              <button class="btn btn-danger" type="button" @click="eliminarFila(fila)">Sí, eliminar</button>
              <button class="btn btn-secondary" type="button" @click="fila.confirmando = false">No</button>
            </div>
          </div>

          <div v-else class="franja-acciones">
            <button
              v-if="seModifico(fila)"
              class="btn btn-primary"
              type="button"
              @click="guardarFila(fila)"
            >
              Guardar
            </button>
            <button class="btn btn-secondary" type="button" @click="pedirEliminar(fila)">
              {{ fila.nueva ? "Descartar" : "Eliminar" }}
            </button>
          </div>
        </div>

        <p v-if="exitoHorarios" class="exito-text center-text">✓ {{ exitoHorarios }}</p>

        <button class="btn btn-secondary btn-block" type="button" @click="agregarFila">
          + Agregar franja
        </button>
        <div class="muted ayuda" style="margin-top: 10px;">
          Los cambios se ven enseguida en tu página de reservas. Los turnos que ya están
          reservados no cambian.
        </div>
      </div>

      <!-- ============ CUENTA ============ -->
      <div class="card card-header">
        <div>
          <strong>Tu cuenta</strong>
          <div class="muted">{{ perfil.nombre }} · Dueño</div>
        </div>
        <router-link class="btn btn-secondary" to="/cambiar-password">Cambiar contraseña</router-link>
      </div>
    </template>
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

.link-fila {
  display: flex;
  gap: 8px;
}

.link-fila input {
  flex: 1;
  min-width: 0;
  color: var(--texto-muted);
}

.ayuda {
  font-size: 12px;
  margin-top: 6px;
}

.franja {
  border-top: 1px solid var(--borde);
  padding: 14px 0 12px;
}

.franja-campos {
  display: grid;
  grid-template-columns: 1.4fr 1fr 1fr;
  gap: 8px;
}

.franja-campos .form-group {
  margin-bottom: 8px;
  min-width: 0;
}

.franja-acciones {
  display: flex;
  gap: 8px;
}

.franja-acciones .btn {
  padding: 8px 14px;
  font-size: 12.5px;
}

.confirmar-borrado {
  background: var(--peligro-bg);
  border-radius: 10px;
  padding: 12px 14px;
}

.confirmar-borrado p {
  margin: 0 0 10px;
  font-size: 13.5px;
}

/* El botón "Cambiar contraseña" es un link: le saco el subrayado */
a.btn {
  text-decoration: none;
}

/* En celulares los datos van uno abajo del otro, y en cada franja el
   día ocupa toda la fila (si no, las horas no entran y se cortan) */
@media (max-width: 480px) {
  .fila {
    flex-direction: column;
    gap: 0;
  }

  .franja-campos {
    grid-template-columns: 1fr 1fr;
  }

  .franja-campos .form-group:first-child {
    grid-column: 1 / -1;
  }
}
</style>
