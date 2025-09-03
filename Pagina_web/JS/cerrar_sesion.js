// cerrar_sesion.js
(() => {
  const LOGIN_URL = "/Pagina_web/html/login.html"; // ajusta si tu ruta es distinta

  function doLogout(evt) {
    if (evt) evt.preventDefault();

    // Borra las claves que usamos en la app (están en sessionStorage)
    const KEYS = ["nombre_estudiante", "apellido_estudiante", "nro_registro_estudiante"];
    for (const k of KEYS) {
      try { sessionStorage.removeItem(k); } catch {}
      try { localStorage.removeItem(k); } catch {}
    }

    // Limpieza total por si en el futuro guardas más cosas
    try { sessionStorage.clear(); } catch {}
    try { localStorage.clear(); } catch {}

    // Redirección sin dejar historial (no vuelve con "atrás")
    window.location.replace(LOGIN_URL);
  }

  document.addEventListener("DOMContentLoaded", () => {
    // Preferimos interceptar el submit del formulario
    const form = document.getElementById("logoutForm");
    if (form) {
      form.addEventListener("submit", doLogout);
    }

    // Fallback por si el botón existe sin formulario
    const btn = document.querySelector(".logout-btn");
    if (btn) {
      btn.addEventListener("click", doLogout);
    }
  });
})();