<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";

const router = useRouter();

const password = ref("");
const password2 = ref("");
const error = ref("");
const exito = ref("");
const cargando = ref(false);

function traducirError(mensaje) {
  if (mensaje.includes("different from the old")) return "La nueva contraseña tiene que ser distinta a la actual.";
  if (mensaje.includes("at least 6")) return "La contraseña tiene que tener al menos 6 caracteres.";
  return "No se pudo cambiar la contraseña. Probá de nuevo.";
}

async function cambiarPassword() {
  error.value = "";
  exito.value = "";

  if (!password.value || !password2.value) {
    error.value = "Completá los dos campos.";
    return;
  }
  if (password.value.length < 6) {
    error.value = "La contraseña tiene que tener al menos 6 caracteres.";
    return;
  }
  if (password.value !== password2.value) {
    error.value = "Las contraseñas no coinciden.";
    return;
  }

  cargando.value = true;

  const { error: err } = await supabase.auth.updateUser({
    password: password.value,
  });

  cargando.value = false;

  if (err) {
    error.value = traducirError(err.message);
    return;
  }

  exito.value = "¡Listo! Tu contraseña se cambió correctamente.";
  password.value = "";
  password2.value = "";
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Cambiar contraseña</h2>
      <p>Elegí una contraseña nueva para tu cuenta</p>
    </div>

    <form class="card" @submit.prevent="cambiarPassword">
      <div class="form-group">
        <label>Nueva contraseña</label>
        <input v-model="password" type="password" placeholder="Mínimo 6 caracteres" />
      </div>
      <div class="form-group">
        <label>Repetir nueva contraseña</label>
        <input v-model="password2" type="password" placeholder="Repetí la contraseña" />
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>
      <p v-if="exito" class="error-text" style="color: var(--exito);">{{ exito }}</p>

      <button class="btn btn-primary btn-block" type="submit" :disabled="cargando">
        {{ cargando ? "Guardando..." : "Cambiar contraseña" }}
      </button>

      <button
        class="btn btn-secondary btn-block"
        type="button"
        style="margin-top: 10px;"
        @click="router.push('/agenda')"
      >
        Volver a la agenda
      </button>
    </form>
  </div>
</template>