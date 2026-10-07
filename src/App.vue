<script setup>
import { ref, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { supabase } from "@/supabase";
import { useHideOnScroll } from "./composables/useHideOnScroll";

const router = useRouter();
const { visible } = useHideOnScroll();

const usuario = ref(null);
let suscripcion = null;

onMounted(async () => {
  // Al cargar la app, me fijo si ya había una sesión abierta
  const { data } = await supabase.auth.getSession();
  usuario.value = data.session?.user ?? null;

  // Cada vez que alguien inicia o cierra sesión, actualizo el header
  const { data: listener } = supabase.auth.onAuthStateChange((_evento, session) => {
    usuario.value = session?.user ?? null;
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
        <router-link to="/reservar">Cliente</router-link>
        <router-link to="/cambiar-password">Clave</router-link>
        <a href="#" @click.prevent="cerrarSesion">Salir</a>
      </template>
      <template v-else>
        <router-link to="/login">Entrar</router-link>
        <router-link to="/registro">Registrarme</router-link>
        <router-link to="/reservar">Cliente</router-link>
      </template>
    </nav>
  </header>

  <router-view v-slot="{ Component }">
    <transition name="page" mode="out-in">
      <component :is="Component" />
    </transition>
  </router-view>
</template>