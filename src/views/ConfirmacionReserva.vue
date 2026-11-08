<script setup>
import { useRoute } from "vue-router";
import { fechaLarga } from "@/utils/fechas";

// Los datos llegan por la URL desde ReservaCliente.vue
const route = useRoute();
const { slug, barberia, servicio, fecha, hora, nombre } = route.query;

// "lunes, 9 de noviembre" -> "Lunes, 9 de noviembre"
const fechaTexto = fechaLarga(fecha);
const dia = fechaTexto.charAt(0).toUpperCase() + fechaTexto.slice(1);
</script>

<template>
  <div class="container">
    <div class="card center-text" style="padding: 34px 24px;">
      <div class="check-circle">
        <svg viewBox="0 0 24 24" fill="none">
          <path
            d="M5 13l4 4L19 7"
            stroke="currentColor"
            stroke-width="3"
            stroke-linecap="round"
            stroke-linejoin="round"
          />
        </svg>
      </div>
      <h2 style="font-family: 'Bebas Neue', sans-serif; font-size: 26px; margin: 0 0 8px;">
        ¡Turno reservado!
      </h2>

      <template v-if="hora">
        <p style="margin: 0 0 4px;">
          <strong>{{ nombre }}</strong>, te esperamos en <strong>{{ barberia }}</strong>
        </p>
        <p style="margin: 0 0 4px;">
          {{ dia }} a las <strong>{{ hora }}</strong>
        </p>
        <p class="muted" style="margin: 0 0 20px;">{{ servicio }}</p>
        <p class="muted" style="margin: 0 0 20px;">
          Sacale captura a esta pantalla. Si no podés ir, avisale a la barbería.
        </p>
      </template>

      <router-link
        v-if="slug"
        class="btn btn-secondary"
        style="text-decoration: none;"
        :to="{ name: 'reservar', params: { slug } }"
      >
        Reservar otro turno
      </router-link>
    </div>
  </div>
</template>
