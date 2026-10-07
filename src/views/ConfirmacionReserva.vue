<script setup>
import { useRoute, useRouter } from "vue-router";

const route = useRoute();
const router = useRouter();
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
        ¡Turno confirmado!
      </h2>
      <p style="margin: 0 0 4px;">
        Reservaste el turno de las <strong>{{ route.query.hora }}</strong> a nombre de
        <strong>{{ route.query.nombre }}</strong>.
      </p>
      <p class="muted" style="margin: 0 0 20px;">
        Te vamos a mandar un recordatorio por WhatsApp unas horas antes del turno.
      </p>
      <button class="btn btn-secondary" @click="router.push('/reservar')">
        Volver a reservar
      </button>
    </div>
  </div>
</template>