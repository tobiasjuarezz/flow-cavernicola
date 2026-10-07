import { onMounted, onUnmounted, ref } from "vue";

// Oculta el header al scrollear hacia abajo y lo vuelve a mostrar al
// scrollear hacia arriba (el mismo comportamiento que usa iOS en Safari
// o en apps nativas con navigation bar).
export function useHideOnScroll() {
  const visible = ref(true);
  let lastY = window.scrollY;
  const umbral = 6; // px mínimos de scroll para reaccionar (evita jitter)

  function onScroll() {
    const currentY = window.scrollY;
    const delta = currentY - lastY;

    if (Math.abs(delta) < umbral) return;

    if (delta > 0 && currentY > 60) {
      visible.value = false; // bajando -> se esconde
    } else {
      visible.value = true; // subiendo -> aparece
    }

    lastY = currentY;
  }

  onMounted(() => window.addEventListener("scroll", onScroll, { passive: true }));
  onUnmounted(() => window.removeEventListener("scroll", onScroll));

  return { visible };
}