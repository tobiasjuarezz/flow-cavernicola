<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRoute, useRouter } from "vue-router";
import { supabase, modoDemo } from "@/supabase";
import { obtenerMiPerfil } from "@/services/db";
import { useHideOnScroll } from "./composables/useHideOnScroll";

const router = useRouter();
const route = useRoute();
const { visible } = useHideOnScroll();

const usuario = ref(null);
const rol = ref(null); // "dueno" o "barbero": decide qué opciones se ven
let suscripcion = null;

async function actualizarUsuario(session) {
  usuario.value = session?.user ?? null;
  rol.value = null;
  if (usuario.value) {
    const { data } = await obtenerMiPerfil();
    rol.value = data?.rol ?? null;
  }
}

onMounted(async () => {
  // Al cargar la app, me fijo si ya había una sesión abierta
  const { data } = await supabase.auth.getSession();
  await actualizarUsuario(data.session);

  // Cada vez que alguien inicia o cierra sesión (o la sesión vence),
  // actualizo el header. Si se quedó sin sesión estando en una página
  // privada, lo saco al login.
  const { data: listener } = supabase.auth.onAuthStateChange((_evento, session) => {
    // setTimeout: Supabase recomienda no hacer consultas dentro del aviso
    setTimeout(() => actualizarUsuario(session), 0);
    if (!session && route.meta.requiereAuth) {
      router.push({ name: "login" });
    }
  });
  suscripcion = listener.subscription;
});

onUnmounted(() => {
  suscripcion?.unsubscribe();
});

async function cerrarSesion() {
  await supabase.auth.signOut();
  router.push("/login");
}
</script>

<template>
  <header class="app-header" :class="{ 'header-hidden': !visible }">
    <div class="brand">
      <div class="brand-mark">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M6 4l6 6-6 6M4 20h16"
            stroke="#161513"
            stroke-width="2.4"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
      <div>
        <h1>Flow Cavernícola</h1>
        <div class="tagline">Turnos sin vueltas</div>
      </div>
    </div>

    <nav>
      <template v-if="usuario">
        <router-link to="/agenda">Agenda</router-link>
        <router-link v-if="rol === 'dueno'" to="/servicios">Servicios</router-link>
        <router-link to="/cambiar-password">Clave</router-link>
        <a href="#" @click.prevent="cerrarSesion">Salir</a>
      </template>
      <template v-else>
        <router-link to="/login">Entrar</router-link>
        <router-link to="/registro">Registrarme</router-link>
      </template>
    </nav>
  </header>

  <div v-if="modoDemo" class="demo-banner">
    Modo demo: no hay base de datos conectada, todo se guarda en este navegador.
  </div>

  <router-view v-slot="{ Component }">
    <transition name="page" mode="out-in">
      <component :is="Component" />
    </transition>
  </router-view>
</template>