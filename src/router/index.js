import { createRouter, createWebHistory } from "vue-router";
import { supabase } from "@/supabase";

import AgendaBarbero from "../views/AgendaBarbero.vue";
import ReservaCliente from "../views/ReservaCliente.vue";
import ConfirmacionReserva from "../views/ConfirmacionReserva.vue";
import LoginView from "../views/LoginView.vue";
import RegistroView from "../views/RegistroView.vue";
import CambiarPasswordView from "../views/CambiarPasswordView.vue";

const routes = [
  {
    path: "/",
    redirect: "/agenda",
  },

  // ---------- Solo para barberos logueados ----------
  {
    path: "/agenda",
    name: "agenda",
    component: AgendaBarbero,
    meta: { requiereAuth: true },
  },
  {
    path: "/cambiar-password",
    name: "cambiar-password",
    component: CambiarPasswordView,
    meta: { requiereAuth: true },
  },

  // ---------- Solo para los que NO están logueados ----------
  {
    path: "/login",
    name: "login",
    component: LoginView,
    meta: { soloInvitados: true },
  },
  {
    path: "/registro",
    name: "registro",
    component: RegistroView,
    meta: { soloInvitados: true },
  },

  // ---------- Públicas (el cliente reserva sin cuenta) ----------
  // Cada barbería tiene su link: /reservar/la-cueva-barber
  {
    path: "/reservar/:slug",
    name: "reservar",
    component: ReservaCliente,
  },
  {
    path: "/confirmacion",
    name: "confirmacion",
    component: ConfirmacionReserva,
  },

  // Cualquier dirección que no exista vuelve al inicio
  {
    path: "/:pathMatch(.*)*",
    redirect: "/",
  },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

// Antes de entrar a cada página, me fijo si hay un usuario logueado
router.beforeEach(async (to) => {
  const { data } = await supabase.auth.getSession();
  const logueado = !!data.session;

  // Página protegida y no está logueado -> al login
  // (guardo a dónde quería ir para mandarlo ahí después de loguearse)
  if (to.meta.requiereAuth && !logueado) {
    return { name: "login", query: { redirect: to.fullPath } };
  }

  // Ya está logueado y quiere ir al login o al registro -> a la agenda
  if (to.meta.soloInvitados && logueado) {
    return { name: "agenda" };
  }
});

export default router;
