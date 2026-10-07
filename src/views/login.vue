<script setup>
import { ref } from "vue";
import { useRoute, useRouter } from "vue-router";
import { supabase } from "@/supabase";

const router = useRouter();
const route = useRoute();

const email = ref("");
const password = ref("");
const error = ref("");
const cargando = ref(false);

function traducirError(mensaje) {
  if (mensaje.includes("Invalid login credentials")) return "Email o contraseña incorrectos.";
  if (mensaje.includes("Email not confirmed")) return "Tenés que confirmar tu email antes de entrar.";
  return "No se pudo iniciar sesión. Probá de nuevo.";
}

async function iniciarSesion() {
  error.value = "";

  if (!email.value.trim() || !password.value) {
    error.value = "Completá tu email y tu contraseña.";
    return;
  }

  cargando.value = true;

  const { error: err } = await supabase.auth.signInWithPassword({
    email: email.value.trim(),
    password: password.value,
  });

  cargando.value = false;

  if (err) {
    error.value = traducirError(err.message);
    return;
  }

  // Si venía de una página protegida, lo devuelvo ahí; si no, a la agenda
  router.push(route.query.redirect || "/agenda");
}
</script>

<template>
  <div class="container">
    <div class="page-title">
      <h2>Iniciá sesión</h2>
      <p>Entrá a la agenda de tu barbería</p>
    </div>

    <form class="card" @submit.prevent="iniciarSesion">
      <div class="form-group">
        <label>Email</label>
        <input v-model="email" type="email" placeholder="tu@email.com" />
      </div>
      <div class="form-group">
        <label>Contraseña</label>
        <input v-model="password" type="password" placeholder="Tu contraseña" />
      </div>

      <p v-if="error" class="error-text">{{ error }}</p>

      <button class="btn btn-primary btn-block" type="submit" :disabled="cargando">
        {{ cargando ? "Entrando..." : "Iniciar sesión" }}
      </button>

      <p class="muted center-text" style="margin: 16px 0 0;">
        ¿No tenés cuenta?
        <router-link to="/registro">Registrate</router-link>
      </p>
    </form>
  </div>
</template>