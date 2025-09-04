(() => {
  const LOGIN_URL = "/Pagina_web/html/login.html";

  function doLogout(evt) {
    if (evt) evt.preventDefault();

    const KEYS = ["nombre_estudiante", "apellido_estudiante", "nro_registro_estudiante"];
    for (const k of KEYS) {
      try { sessionStorage.removeItem(k); } catch {}
      try { localStorage.removeItem(k); } catch {}
    }

    try { sessionStorage.clear(); } catch {}
    try { localStorage.clear(); } catch {}

    window.location.replace(LOGIN_URL);
  }

  document.addEventListener("DOMContentLoaded", () => {

    const form = document.getElementById("logoutForm");
    if (form) {
      form.addEventListener("submit", doLogout);
    }


    const btn = document.querySelector(".logout-btn");
    if (btn) {
      btn.addEventListener("click", doLogout);
    }
  });
})();