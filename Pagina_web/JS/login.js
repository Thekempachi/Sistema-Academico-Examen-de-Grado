// /Pagina_web/JS/login.js
(() => {
  const ENDPOINT = "https://im-ventas-de-computadoras.com/Sistema_Academico/login.php";
  const DEST = {
    DOCENTE: "/Pagina_web/html/docente.html",
    ESTUDIANTE: "/Pagina_web/html/estudiantes.html",
  };

  let currentRole = "ESTUDIANTE";

  function $(id) { return document.getElementById(id); }
  function showAlert(msg) {
    const box = $("alert");
    $("alert-text").textContent = msg;
    box.classList.remove("hidden");
  }
  function hideAlert() {
    $("alert").classList.add("hidden");
  }

  function selectRole(role) {
    currentRole = role;

    $("role-estudiante").classList.toggle("active", role === "ESTUDIANTE");
    $("role-docente").classList.toggle("active", role === "DOCENTE");

    const label = $("usuario-label");
    const input = $("usuario");
    const roleText = $("selected-role-text");

    if (role === "DOCENTE") {
      label.textContent = "Correo (email)";
      input.type = "email";
      input.placeholder = "docente@universidad.edu";
      roleText.textContent = "docente";
    } else {
      label.textContent = "Nro. de registro";
      input.type = "text";
      input.placeholder = "NR-XXXX";
      roleText.textContent = "estudiante";
    }

    input.focus();
    hideAlert();
  }

  function togglePassword() {
    const input = $("password");
    const eye = $("eye-icon");
    const isPwd = input.type === "password";
    input.type = isPwd ? "text" : "password";
    eye.style.opacity = isPwd ? 0.7 : 1;
  }

  async function handleSubmit(e) {
    e.preventDefault();
    hideAlert();

    const usuario  = $("usuario").value.trim();
    const password = $("password").value;

    if (!usuario || !password) {
      showAlert("Complete todos los campos.");
      return;
    }

    const body = new URLSearchParams({ rol: currentRole, usuario, password });

    try {
      const resp = await fetch(ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body,
      });

      const text = await resp.text();
      let data;
      try { data = JSON.parse(text); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw:text }; }

      if (resp.ok && data.ok) {
        if (data.rol === "ESTUDIANTE") {
          sessionStorage.setItem("nombre_estudiante", data.nombre || "");
          sessionStorage.setItem("apellido_estudiante", data.apellido || "");
          sessionStorage.setItem("nro_registro_estudiante", usuario);
        } else if (data.rol === "DOCENTE") {
          if (data.docente) {
            localStorage.setItem("docente_email", data.docente.email || usuario);
            localStorage.setItem("docente_nombre", data.docente.nombre || "");
            localStorage.setItem("docente_apellido", data.docente.apellido || "");
            if (data.docente.id_docente) {
              localStorage.setItem("docente_id", String(data.docente.id_docente));
            }
          } else {
            localStorage.setItem("docente_email", usuario);
          }
        }

        window.location.href = data.redirect || DEST[data.rol] || "/";
      } else if (resp.status === 401 || data.error === "CREDENCIALES_INVALIDAS") {
        showAlert("Usuario o contraseña incorrectos.");
      } else if (resp.status === 400 || data.error === "FALTAN_DATOS") {
        showAlert("Complete todos los campos.");
      } else if (resp.status === 403) {
        showAlert("Acceso no permitido para este rol.");
      } else {
        console.error("Respuesta cruda:", text);
        showAlert(`Error del servidor (${resp.status}).`);
      }
    } catch (err) {
      console.error(err);
      showAlert("Error de conexión (¿CORS/red?).");
    }
  }

  function forgotPassword() {
    alert("Contacte a soporte académico para restablecer su contraseña.");
  }

  document.addEventListener("DOMContentLoaded", () => {
    $("role-estudiante")?.addEventListener("click", () => selectRole("ESTUDIANTE"));
    $("role-docente")?.addEventListener("click", () => selectRole("DOCENTE"));

    $("password-toggle")?.addEventListener("click", togglePassword);
    $("forgot-btn")?.addEventListener("click", forgotPassword);

    $("loginForm")?.addEventListener("submit", handleSubmit);

    selectRole("ESTUDIANTE");
  });
})();