<script setup>
defineProps({
  turno: { type: Object, required: true },
});
defineEmits(["cerrar", "completar", "cancelar"]);
</script>

<template>
  <div class="overlay" @click.self="$emit('cerrar')">
    <div class="modal card">
      <div class="page-title" style="margin-bottom: 12px;">
        <h2 style="font-size: 24px;">Turno {{ turno.hora }}</h2>
      </div>

      <div class="form-group">
        <label>Cliente</label>
        <div>{{ turno.cliente }}</div>
      </div>
      <div class="form-group">
        <label>Teléfono</label>
        <div>{{ turno.telefono }}</div>
      </div>
      <div class="form-group">
        <label>Servicio</label>
        <div>{{ turno.servicio }}</div>
      </div>
      <div class="form-group">
        <label>Estado</label>
        <span class="badge" :class="'badge-' + turno.estado">{{ turno.estado }}</span>
      </div>

      <div style="display: flex; gap: 8px; margin-top: 18px; flex-wrap: wrap;">
        <button class="btn btn-success" @click="$emit('completar')">
          Marcar completado
        </button>
        <button class="btn btn-danger" @click="$emit('cancelar')">
          Cancelar turno
        </button>
        <button class="btn btn-secondary" @click="$emit('cerrar')">
          Cerrar
        </button>
      </div>
    </div>
  </div>
</template>
