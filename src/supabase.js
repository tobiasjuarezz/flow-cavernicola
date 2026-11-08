import { createClient } from "@supabase/supabase-js";

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

// Si el .env tiene datos reales de Supabase, uso Supabase.
// Si está vacío o tiene los datos de ejemplo (.env.example), uso el
// "modo demo": el login se imita acá abajo y las tablas las imita
// services/dbDemo.js. Todo se guarda en el navegador (localStorage).
const hayConfiguracion =
  !!supabaseUrl &&
  !!supabaseKey &&
  !supabaseUrl.includes("abcdefgh") &&
  supabaseKey.length > 40;

export const modoDemo = !hayConfiguracion;

export const supabase = hayConfiguracion
  ? createClient(supabaseUrl, supabaseKey)
  : crearSupabaseDemo();

if (modoDemo) {
  console.warn(
    "[Flow Cavernícola] Modo demo: sin base de datos, los datos se guardan en este navegador."
  );
}

// ------------------------------------------------------------------
// MODO DEMO: imita supabase.auth (registro, login, logout, cambiar
// clave). Las tablas NO van acá: eso lo hace services/dbDemo.js.
// ------------------------------------------------------------------
function crearSupabaseDemo() {
  const CLAVE_USUARIOS = "fc_usuarios";
  const CLAVE_SESION = "fc_sesion";

  function leer(clave, porDefecto) {
    try {
      const valor = localStorage.getItem(clave);
      return valor ? JSON.parse(valor) : porDefecto;
    } catch {
      return porDefecto;
    }
  }

  function guardar(clave, valor) {
    try {
      localStorage.setItem(clave, JSON.stringify(valor));
    } catch {
      // si el navegador no deja guardar, sigue funcionando en memoria
    }
  }

  function generarId() {
    return Date.now().toString(36) + Math.random().toString(36).slice(2, 8);
  }

  // El usuario que se devuelve nunca incluye la contraseña
  function usuarioPublico(u) {
    return u
      ? { id: u.id, email: u.email, user_metadata: u.user_metadata }
      : null;
  }

  function usuarioActual() {
    const id = leer(CLAVE_SESION, null);
    const usuarios = leer(CLAVE_USUARIOS, []);
    return usuarios.find((u) => u.id === id) || null;
  }

  function sesionActual() {
    const u = usuarioActual();
    return u ? { user: usuarioPublico(u) } : null;
  }

  const oyentes = new Set();

  function avisar(evento) {
    const sesion = sesionActual();
    oyentes.forEach((fn) => fn(evento, sesion));
  }

  const auth = {
    async getSession() {
      return { data: { session: sesionActual() }, error: null };
    },

    async getUser() {
      return { data: { user: usuarioPublico(usuarioActual()) }, error: null };
    },

    async signUp({ email, password, options }) {
      if (!password || password.length < 6) {
        return {
          data: { user: null, session: null },
          error: { message: "Password should be at least 6 characters" },
        };
      }

      const usuarios = leer(CLAVE_USUARIOS, []);
      const mail = email.toLowerCase();

      if (usuarios.some((u) => u.email === mail)) {
        return {
          data: { user: null, session: null },
          error: { message: "User already registered" },
        };
      }

      const nuevo = {
        id: generarId(),
        email: mail,
        password,
        user_metadata: options?.data || {},
      };

      usuarios.push(nuevo);
      guardar(CLAVE_USUARIOS, usuarios);
      guardar(CLAVE_SESION, nuevo.id);
      avisar("SIGNED_IN");

      return {
        data: { user: usuarioPublico(nuevo), session: sesionActual() },
        error: null,
      };
    },

    async signInWithPassword({ email, password }) {
      const usuarios = leer(CLAVE_USUARIOS, []);
      const u = usuarios.find(
        (x) => x.email === email.toLowerCase() && x.password === password
      );

      if (!u) {
        return {
          data: { user: null, session: null },
          error: { message: "Invalid login credentials" },
        };
      }

      guardar(CLAVE_SESION, u.id);
      avisar("SIGNED_IN");

      return {
        data: { user: usuarioPublico(u), session: sesionActual() },
        error: null,
      };
    },

    async signOut() {
      guardar(CLAVE_SESION, null);
      avisar("SIGNED_OUT");
      return { error: null };
    },

    async updateUser({ password }) {
      const actual = usuarioActual();
      if (!actual) {
        return { data: { user: null }, error: { message: "Auth session missing" } };
      }
      if (!password || password.length < 6) {
        return {
          data: { user: null },
          error: { message: "Password should be at least 6 characters" },
        };
      }
      if (password === actual.password) {
        return {
          data: { user: null },
          error: { message: "New password should be different from the old password." },
        };
      }

      const usuarios = leer(CLAVE_USUARIOS, []);
      const u = usuarios.find((x) => x.id === actual.id);
      u.password = password;
      guardar(CLAVE_USUARIOS, usuarios);
      avisar("USER_UPDATED");

      return { data: { user: usuarioPublico(u) }, error: null };
    },

    onAuthStateChange(callback) {
      oyentes.add(callback);
      return {
        data: {
          subscription: { unsubscribe: () => oyentes.delete(callback) },
        },
      };
    },
  };

  return { auth };
}
