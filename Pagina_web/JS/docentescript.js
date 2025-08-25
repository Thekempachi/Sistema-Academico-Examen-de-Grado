// Variables globales
let currentTab = "materias"
let currentSubject = "MAT-101"

// Inicialización
document.addEventListener("DOMContentLoaded", () => {
  showTab("materias")
  loadGrades()
})

// Gestión de tabs
function showTab(tabName) {
  // Ocultar todos los contenidos
  document.querySelectorAll(".tab-content").forEach((content) => {
    content.classList.remove("active")
  })

  // Desactivar todos los botones
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.remove("active")
  })

  // Mostrar contenido activo
  document.getElementById(tabName).classList.add("active")

  // Activar botón correspondiente
  event.target.classList.add("active")

  currentTab = tabName
}

// Funciones de materias
function viewStudents(subjectCode) {
  showTab("estudiantes")
  filterStudentsBySubject(subjectCode)

  // Actualizar botón activo
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.remove("active")
  })
  document.querySelector("[onclick=\"showTab('estudiantes')\"]").classList.add("active")
}

function viewGrades(subjectCode) {
  showTab("calificaciones")
  document.getElementById("subject-select").value = subjectCode
  loadGrades()

  // Actualizar botón activo
  document.querySelectorAll(".tab-btn").forEach((btn) => {
    btn.classList.remove("active")
  })
  document.querySelector("[onclick=\"showTab('calificaciones')\"]").classList.add("active")
}

// Funciones de calificaciones
function loadGrades() {
  const subjectCode = document.getElementById("subject-select").value
  currentSubject = subjectCode

  // Datos simulados por materia
  const gradesData = {
    "MAT-101": [
      { name: "Ana Rodríguez", code: "2021001", grades: [85, 78, 92, 88] },
      { name: "Carlos Mendoza", code: "2021002", grades: [72, 68, 75, 70] },
      { name: "Laura Jiménez", code: "2021003", grades: [95, 89, 93, 91] },
      { name: "Pedro Sánchez", code: "2021004", grades: [68, 72, 65, 69] },
      { name: "María López", code: "2021005", grades: [88, 85, 90, 87] },
    ],
    "MAT-201": [
      { name: "Ana Rodríguez", code: "2021001", grades: [82, 79, 85, 83] },
      { name: "Laura Jiménez", code: "2021003", grades: [91, 88, 94, 90] },
      { name: "Diego Herrera", code: "2021006", grades: [75, 78, 73, 76] },
      { name: "Sofia Ramírez", code: "2021007", grades: [89, 92, 87, 90] },
    ],
    "EST-301": [
      { name: "Carlos Mendoza", code: "2021002", grades: [78, 75, 82, 79] },
      { name: "Laura Jiménez", code: "2021003", grades: [93, 90, 95, 92] },
      { name: "Diego Herrera", code: "2021006", grades: [71, 74, 69, 72] },
      { name: "Sofia Ramírez", code: "2021007", grades: [86, 89, 84, 87] },
    ],
  }

  const tbody = document.getElementById("grades-tbody")
  tbody.innerHTML = ""

  const students = gradesData[subjectCode] || []

  students.forEach((student) => {
    const average = (student.grades.reduce((a, b) => a + b, 0) / student.grades.length).toFixed(1)
    const status = average >= 70 ? "approved" : "failed"
    const statusText = average >= 70 ? "Aprobado" : "Reprobado"

    const row = document.createElement("tr")
    row.innerHTML = `
            <td>${student.name}</td>
            <td>${student.code}</td>
            <td><input type="number" value="${student.grades[0]}" min="0" max="100" onchange="calculateAverage(this)"></td>
            <td><input type="number" value="${student.grades[1]}" min="0" max="100" onchange="calculateAverage(this)"></td>
            <td><input type="number" value="${student.grades[2]}" min="0" max="100" onchange="calculateAverage(this)"></td>
            <td><input type="number" value="${student.grades[3]}" min="0" max="100" onchange="calculateAverage(this)"></td>
            <td class="average">${average}</td>
            <td><span class="status ${status}">${statusText}</span></td>
        `
    tbody.appendChild(row)
  })
}

function calculateAverage(input) {
  const row = input.closest("tr")
  const gradeInputs = row.querySelectorAll('input[type="number"]')
  let total = 0
  let count = 0

  gradeInputs.forEach((gradeInput) => {
    const value = Number.parseFloat(gradeInput.value)
    if (!isNaN(value)) {
      total += value
      count++
    }
  })

  const average = count > 0 ? (total / count).toFixed(1) : 0
  const averageCell = row.querySelector(".average")
  const statusCell = row.querySelector(".status")

  averageCell.textContent = average

  if (average >= 70) {
    statusCell.textContent = "Aprobado"
    statusCell.className = "status approved"
  } else {
    statusCell.textContent = "Reprobado"
    statusCell.className = "status failed"
  }
}

function saveGrades() {
  // Simulación de guardado
  alert("Calificaciones guardadas exitosamente")
}

function exportGrades() {
  // Simulación de exportación
  alert("Exportando calificaciones a Excel...")
}

// Funciones de estudiantes
function filterStudents() {
  // Implementar filtro por materia
  console.log("Filtrando estudiantes...")
}

function searchStudents(query) {
  // Implementar búsqueda de estudiantes
  console.log("Buscando:", query)
}

function filterStudentsBySubject(subjectCode) {
  // Filtrar estudiantes por materia específica
  console.log("Filtrando por materia:", subjectCode)
}

function sendMessage(studentCode) {
  alert(`Enviando mensaje al estudiante ${studentCode}`)
}

function viewProfile(studentCode) {
  alert(`Viendo perfil del estudiante ${studentCode}`)
}

// Funciones de mensajes
function newMessage() {
  alert("Abriendo formulario de nuevo mensaje...")
}

function filterMessages(type) {
  // Actualizar filtros activos
  document.querySelectorAll(".filter-btn").forEach((btn) => {
    btn.classList.remove("active")
  })
  event.target.classList.add("active")

  // Implementar filtrado de mensajes
  console.log("Filtrando mensajes:", type)
}

// Funciones de reportes
function generateReport(type) {
  const reportTypes = {
    grades: "Reporte de Calificaciones",
    attendance: "Reporte de Asistencia",
    performance: "Análisis de Rendimiento",
    semester: "Resumen Semestral",
  }

  alert(`Generando ${reportTypes[type]}...`)
}

// Funciones de utilidad
function showNotification(message, type = "info") {
  // Crear notificación temporal
  const notification = document.createElement("div")
  notification.className = `notification ${type}`
  notification.textContent = message
  notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 1rem;
        background-color: var(--primary);
        color: var(--primary-foreground);
        border-radius: 0.5rem;
        z-index: 1000;
        animation: slideIn 0.3s ease-out;
    `

  document.body.appendChild(notification)

  setTimeout(() => {
    notification.remove()
  }, 3000)
}

// Estilos para animaciones
const style = document.createElement("style")
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
`
document.head.appendChild(style)
