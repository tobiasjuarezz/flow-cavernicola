import { createClient } from "@supabase/supabase-js";
 
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseKey = import.meta.env.VITE_SUPABASE_ANON_KEY;
 
// Si el .env tiene datos reales de Supabase, uso Supabase.
// Si está vacío o tiene los datos de ejemplo, uso el "modo demo":
// todo se guarda en el navegador (localStorage) con los mismos métodos
// que Supabase, así el resto del código no cambia.
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
// MODO DEMO: imita supabase.auth y supabase.from("turnos")
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
 
  // ---------- Consultas tipo supabase.from("turnos") ----------
 
  function fechaDeHoy() {
    const d = new Date();
    d.setMinutes(d.getMinutes() - d.getTimezoneOffset());
    return d.toISOString().slice(0, 10);
  }
 
  // Supabase devuelve la hora como "09:00:00"
  function normalizarHora(hora) {
    return hora && hora.length === 5 ? hora + ":00" : hora;
  }
 
  // Igual que el índice "turnos_sin_pisar" del SQL
  function seRepite(filas, turno, idIgnorado) {
    return filas.some(
      (f) =>
        f.id !== idIgnorado &&
        f.barbero_id === turno.barbero_id &&
        f.fecha === turno.fecha &&
        f.hora === turno.hora &&
        f.estado !== "cancelado" &&
        turno.estado !== "cancelado"
    );
  }
 
  class Consulta {
    constructor(tabla) {
      this.clave = "fc_tabla_" + tabla;
      this.operacion = "select";
      this.datos = null;
      this.filtros = [];
      this.orden = null;
      this.limite = null;
    }
 
    select() {
      return this;
    }
 
    insert(datos) {
      this.operacion = "insert";
      this.datos = datos;
      return this;
    }
 
    update(datos) {
      this.operacion = "update";
      this.datos = datos;
      return this;
    }
 
    delete() {
      this.operacion = "delete";
      return this;
    }
 
    eq(columna, valor) {
      this.filtros.push([columna, valor]);
      return this;
    }
 
    order(columna, { ascending = true } = {}) {
      this.orden = { columna, ascending };
      return this;
    }
 
    limit(n) {
      this.limite = n;
      return this;
    }
 
    // Permite hacer "await" de la consulta, igual que en Supabase
    then(resolve, reject) {
      return Promise.resolve()
        .then(() => this.ejecutar())
        .then(resolve, reject);
    }
 
    cumpleFiltros(fila) {
      return this.filtros.every(([c, v]) => String(fila[c]) === String(v));
    }
 
    ejecutar() {
      const usuario = usuarioActual();
      if (!usuario) {
        return { data: null, error: { message: "No hay sesión iniciada" } };
      }
 
      let filas = leer(this.clave, []);
      const mias = (f) => f.barbero_id === usuario.id; // como las políticas RLS
 
      if (this.operacion === "select") {
        let resultado = filas.filter((f) => mias(f) && this.cumpleFiltros(f));
        if (this.orden) {
          const { columna, ascending } = this.orden;
          resultado.sort((a, b) =>
            a[columna] > b[columna] ? (ascending ? 1 : -1) : a[columna] < b[columna] ? (ascending ? -1 : 1) : 0
          );
        }
        if (this.limite) resultado = resultado.slice(0, this.limite);
        return { data: resultado, error: null };
      }
 
      if (this.operacion === "insert") {
        const lista = Array.isArray(this.datos) ? this.datos : [this.datos];
        let siguienteId = filas.reduce((max, f) => Math.max(max, f.id), 0) + 1;
        const nuevas = [];
 
        for (const d of lista) {
          const turno = {
            fecha: fechaDeHoy(),
            servicio: "Corte",
            estado: "pendiente",
            ...d,
            id: siguienteId++,
            barbero_id: usuario.id,
            created_at: new Date().toISOString(),
          };
          turno.hora = normalizarHora(turno.hora);
 
          if (seRepite([...filas, ...nuevas], turno)) {
            return { data: null, error: { code: "23505", message: "duplicate key value" } };
          }
          nuevas.push(turno);
        }
 
        guardar(this.clave, [...filas, ...nuevas]);
        return { data: nuevas, error: null };
      }
 
      if (this.operacion === "update") {
        const actualizadas = [];
        const nuevasFilas = filas.map((f) => {
          if (!mias(f) || !this.cumpleFiltros(f)) return f;
          const cambiada = { ...f, ...this.datos, id: f.id, barbero_id: f.barbero_id };
          cambiada.hora = normalizarHora(cambiada.hora);
          actualizadas.push(cambiada);
          return cambiada;
        });
 
        for (const t of actualizadas) {
          if (seRepite(nuevasFilas, t, t.id)) {
            return { data: null, error: { code: "23505", message: "duplicate key value" } };
          }
        }
 
        guardar(this.clave, nuevasFilas);
        return { data: actualizadas, error: null };
      }
 
      if (this.operacion === "delete") {
        const quedan = filas.filter((f) => !(mias(f) && this.cumpleFiltros(f)));
        guardar(this.clave, quedan);
        return { data: null, error: null };
      }
 
      return { data: null, error: { message: "Operación no soportada" } };
    }
  }
 
  return {
    auth,
    from: (tabla) => new Consulta(tabla),
  };
}
 