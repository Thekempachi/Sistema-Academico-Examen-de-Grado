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