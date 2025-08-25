// Global variables
let currentMonth = new Date().getMonth()
let currentYear = new Date().getFullYear()
const months = [
  "Enero",
  "Febrero",
  "Marzo",
  "Abril",
  "Mayo",
  "Junio",
  "Julio",
  "Agosto",
  "Septiembre",
  "Octubre",
  "Noviembre",
  "Diciembre",
]

// Initialize the application
document.addEventListener("DOMContentLoaded", () => {
  generateCalendar()
  showSection("inicio")
})

// Toggle sidebar function
function toggleSidebar() {
  const sidebar = document.getElementById("sidebar")
  sidebar.classList.toggle("active")
}

// Show different sections
function showSection(sectionId) {
  // Hide all sections
  const sections = document.querySelectorAll(".content-section")
  sections.forEach((section) => {
    section.classList.remove("active")
  })

  // Show selected section
  const targetSection = document.getElementById(sectionId)
  if (targetSection) {
    targetSection.classList.add("active")
  }

  const sidebar = document.getElementById("sidebar")
  sidebar.classList.remove("active")

  // Special handling for calendar section
  if (sectionId === "calendario") {
    generateCalendar()
  }
}

// Calendar functions
function generateCalendar() {
  const calendarGrid = document.querySelector(".calendar-grid")
  const currentMonthElement = document.getElementById("currentMonth")

  // Update month display
  currentMonthElement.textContent = `${months[currentMonth]} ${currentYear}`

  // Clear existing calendar days (keep headers)
  const existingDays = calendarGrid.querySelectorAll(".calendar-day:not(.header)")
  existingDays.forEach((day) => day.remove())

  // Get first day of month and number of days
  const firstDay = new Date(currentYear, currentMonth, 1).getDay()
  const daysInMonth = new Date(currentYear, currentMonth + 1, 0).getDate()
  const today = new Date()

  // Add empty cells for days before month starts
  for (let i = 0; i < firstDay; i++) {
    const emptyDay = document.createElement("div")
    emptyDay.className = "calendar-day"
    calendarGrid.appendChild(emptyDay)
  }

  // Add days of the month
  for (let day = 1; day <= daysInMonth; day++) {
    const dayElement = document.createElement("div")
    dayElement.className = "calendar-day"
    dayElement.textContent = day

    // Highlight today
    if (currentYear === today.getFullYear() && currentMonth === today.getMonth() && day === today.getDate()) {
      dayElement.classList.add("today")
    }

    // Add some sample events
    if (day === 15 || day === 22 || day === 28) {
      dayElement.classList.add("event")
      dayElement.title = "Examen programado"
    }

    calendarGrid.appendChild(dayElement)
  }
}

function previousMonth() {
  currentMonth--
  if (currentMonth < 0) {
    currentMonth = 11
    currentYear--
  }
  generateCalendar()
}

function nextMonth() {
  currentMonth++
  if (currentMonth > 11) {
    currentMonth = 0
    currentYear++
  }
  generateCalendar()
}

// Logout function
function logout() {
  if (confirm("¿Estás seguro de que deseas cerrar sesión?")) {
    alert("Sesión cerrada exitosamente")
    // Here you would typically redirect to login page
    // window.location.href = 'login.html';
  }
}

// Contact support function
function contactSupport() {
  alert(
    "Conectando con Soporte para Estudiantes...\n\nPuedes contactarnos por:\n• WhatsApp: +591 70000000\n• Email: soporte@unb.edu.bo\n• Horario: Lunes a Viernes 8:00-18:00",
  )
}

// Close sidebar when clicking outside (mobile)
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

// Handle window resize
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

  // Actualizar UI de selección de rol
  document.querySelectorAll(".role-selector").forEach((btn) => {
    btn.classList.remove("active")
  })
  document.getElementById(`role-${role}`).classList.add("active")

  // Actualizar texto del formulario
  const roleTexts = {
    estudiante: "estudiante",
    docente: "docente",
    administrativo: "personal administrativo",
  }
  document.getElementById("selected-role-text").textContent = roleTexts[role]

  // Limpiar mensajes
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

