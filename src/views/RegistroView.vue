<script setup>
import { ref } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { validarNombre, validarEmail } from "@/utils/validaciones";

const router = useRouter();

const barberia = ref("");
const nombre = ref("");
const email = ref("");
const password = ref("");
const password2 = ref("");
const error = ref("");
const cargando = ref(false);

function traducirError(mensaje) {
  if (mensaje.includes("already registered")) return "Ese email ya está registrado.";
  if (mensaje.includes("at least 6")) return "La contraseña tiene que tener al menos 6 caracteres.";
  if (mensaje.includes("invalid")) return "El email no es válido.";
  return "No se pudo crear la cuenta. Probá de nuevo.";
}

async function registrar() {
  error.value = "";

  if (!barberia.value.trim() || !nombre.value.trim() || !email.value.trim() || !password.value) {
    error.value = "Completá todos los campos.";
    return;
  }
  if (barberia.value.trim().length < 3) {
    error.value = "El nombre de la barbería tiene que tener al menos 3 caracteres.";
    return;
  }

  const errorDatos = validarNombre(nombre.value) || validarEmail(email.value);
  if (errorDatos) {
    error.value = errorDatos;
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

  const { error: err } = await supabase.auth.signUp({
    email: email.value.trim(),
    password: password.value,
    // Estos datos viajan en user_metadata. En la base, el trigger
    // "al_registrarse_usuario" los usa para crear la barbería y el perfil.
    options: {
      data: { barberia: barberia.value.trim(), nombre: nombre.value.trim() },
    },
  });

  cargando.value = false;

  if (err) {
    error.value = traducirError(err.message);
    return;
  }

  router.push("/agenda");
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Creá tu cuenta</h2>
      <p>Registrá tu barbería y empezá a ordenar tus turnos</p>
    </div>

    <form class="card" novalidate @submit.prevent="registrar">
      <div class="form-group">
        <label>Nombre de la barbería</label>
        <input v-model="barberia" type="text" placeholder="Ej: Barbería El Tano" />
      </div>
      <div class="form-group">
        <label>Tu nombre</label>
        <input v-model="nombre" type="text" placeholder="Ej: Nico" />
      </div>
      <div class="form-group">
        <label>Email</label>
        <input v-model="email" type="email" placeholder="tu@email.com" />
      </div>
      <div class="form-group">
        <label>Contraseña</label>
        <input v-model="password" type="password" placeholder="Mínimo 6 caracteres" />
      </div>
      <div class="form-group">
        <label>Repetir contraseña</label>
        <input v-model="password2" type="password" placeholder="Repetí la contraseña" />
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>

      <button class="btn btn-primary btn-block" type="submit" :disabled="cargando">
        {{ cargando ? "Creando cuenta..." : "Registrarme" }}
      </button>

      <p class="muted center-text" style="margin: 16px 0 0;">
        ¿Ya tenés cuenta?
        <router-link to="/login">Iniciá sesión</router-link>
      </p>
    </form>
  </div>
</template>