// Initialize the application
document.addEventListener("DOMContentLoaded", () => {
  showSection("inicio")
})

// Toggle sidebar function
function toggleSidebar() {
  const sidebar = document.getElementById("sidebar")
  sidebar.classList.toggle("active")
}

function showSection(sectionId) {
  const sections = document.querySelectorAll(".content-section");
  sections.forEach((section) => {
    section.classList.remove("active");
    section.setAttribute("hidden", "");
  });

  const targetSection = document.getElementById(sectionId);
  if (targetSection) {
    targetSection.classList.add("active");
    targetSection.removeAttribute("hidden");
  }

  const sidebar = document.getElementById("sidebar");
  if (sidebar) sidebar.classList.remove("active");
}

function navigateTo(hashOrId) {
  const id = (hashOrId || "").startsWith("#") ? hashOrId.slice(1) : hashOrId;
  showSection(id);
}


// Logout function
function logout() {
  if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
    alert("Sesión cerrada exitosamente")
  }
}

function contactSupport() {
  alert(
    "Conectando con Soporte para Estudiantes...\n\nPuedes contactarnos por:\n• WhatsApp: +591 70000000\n• Email: soporte@unb.edu.bo\n• Horario: Lunes a Viernes 8:00-18:00",
  )
}

document.addEventListener("click", (event) => {
  const sidebar = document.getElementById("sidebar")
  const menuToggle = document.querySelector(".menu-toggle-btn")

  if (
    window.innerWidth <= 480 &&
    sidebar.classList.contains("active") &&
    !sidebar.contains(event.target) &&
    !menuToggle.contains(event.target)
  ) {
    sidebar.classList.remove("active")
  }
})

window.addEventListener("resize", () => {
  const sidebar = document.getElementById("sidebar")
  if (window.innerWidth > 480) {
    sidebar.classList.remove("active")
  }
})

function registerSubject(subjectName) {
  if (confirm(`¿Deseas registrarte en la materia "${subjectName}"?`)) {
    alert(
      `Te has registrado exitosamente en ${subjectName}.\n\nRecibirás un correo de confirmación con los detalles del pago y horarios.`,
    )
  }
}
let selectedRole = "estudiante"
let isLoading = false

function selectRole(role) {
  selectedRole = role


  document.querySelectorAll(".role-selector").forEach((btn) => {
    btn.classList.remove("active")
  })
  document.getElementById(`role-${role}`).classList.add("active")

  const roleTexts = {
    estudiante: "estudiante",
    docente: "docente",
    administrativo: "personal administrativo",
  }
  document.getElementById("selected-role-text").textContent = roleTexts[role]

  hideMessage()
}

function togglePassword() {
  const passwordInput = document.getElementById("password")
  const eyeIcon = document.getElementById("eye-icon")

  if (passwordInput.type === "password") {
    passwordInput.type = "text"
    eyeIcon.innerHTML = `
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.875 18.825A10.05 10.05 0 0112 19c-4.478 0-8.268-2.943-9.543-7a9.97 9.97 0 011.563-3.029m5.858.908a3 3 0 114.243 4.243M9.878 9.878l4.242 4.242M9.878 9.878L3 3m6.878 6.878L21 21"/>
        `
  } else {
    passwordInput.type = "password"
    eyeIcon.innerHTML = `
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z"/>
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z"/>
        `
  }
}

function showMessage(type, text) {
  const messageDiv = document.getElementById("message")
  messageDiv.className = `alert ${type}`
  messageDiv.textContent = text
  messageDiv.classList.remove("hidden")
}

function hideMessage() {
  const messageDiv = document.getElementById("message")
  messageDiv.classList.add("hidden")
}

function validateForm(email, password) {
  if (!email || !password) {
    showMessage("error", "Por favor complete todos los campos")
    return false
  }

  if (!email.includes("@")) {
    showMessage("error", "Por favor ingrese un email válido")
    return false
  }

  if (password.length < 6) {
    showMessage("error", "La contraseña debe tener al menos 6 caracteres")
    return false
  }

  return true
}

function handleLogin(event) {
  event.preventDefault()

  if (isLoading) return

  const email = document.getElementById("email").value
  const password = document.getElementById("password").value

  if (!validateForm(email, password)) return

  isLoading = true
  const loginBtn = document.getElementById("login-btn")
  loginBtn.textContent = "Verificando..."
  loginBtn.disabled = true

  // Simulación de autenticación
  setTimeout(() => {
    const mockAuth = {
      estudiante: email.includes("estudiante"),
      docente: email.includes("docente"),
      administrativo: email.includes("admin"),
    }

    if (mockAuth[selectedRole]) {
      const roleNames = {
        estudiante: "Estudiante",
        docente: "Docente",
        administrativo: "Personal Administrativo",
      }

      showMessage("success", `¡Bienvenido! Acceso autorizado como ${roleNames[selectedRole]}`)

      setTimeout(() => {
        window.location.href = `${selectedRole}.php`
      }, 1500)
    } else {
      showMessage("error", "Credenciales incorrectas. Verifique su email y contraseña.")
    }

    isLoading = false
    loginBtn.textContent = "Iniciar Sesión"
    loginBtn.disabled = false
  }, 2000)
}

function showForgotPassword() {
  showMessage("error", "Contacte al administrador del sistema para recuperar su contraseña")
}