// script_notas_estudiante.js
(() => {
  const ENDPOINT_NOTAS = "https://im-ventas-de-computadoras.com/Sistema_Academico/notas_estudiante.php";

  document.addEventListener("DOMContentLoaded", () => {
    cargarNotasEstudiante();
  });

  /* ========================= ESTADO / SESSION ========================= */
  function getNR() {
    return sessionStorage.getItem("nro_registro_estudiante") || "";
  }

  /* ========================= CARGA Y RENDER =========================== */
  async function cargarNotasEstudiante() {
    const cont = document.getElementById("notas-container");
    if (!cont) return;

    const nro_registro = getNR();
    if (!nro_registro) {
      cont.innerHTML = `<p class="error">No se encontró el Nro. de registro en esta sesión. Inicie sesión nuevamente.</p>`;
      return;
    }

    cont.innerHTML = `<p>Cargando notas...</p>`;

    try {
      const body = new URLSearchParams({ nro_registro });
      const resp = await fetch(ENDPOINT_NOTAS, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body
      });

      const raw = await resp.text();
      let data;
      try { data = JSON.parse(raw); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw }; }

      if (!resp.ok || !data.ok) {
        const msg = data.msg || data.error || `HTTP ${resp.status}`;
        cont.innerHTML = `<p class="error">No se pudieron cargar las notas. ${escapeHTML(String(msg))}</p>`;
        console.error("notas_estudiante.php respuesta:", raw);
        return;
      }

      const semestres = Array.isArray(data.semestres) ? data.semestres : [];
      const promedio = data.promedio_final; // entero o null

      if (semestres.length === 0) {
        cont.innerHTML = renderPromedioCard(promedio) + `<p>No se encontraron notas registradas.</p>`;
        return;
      }

      // Orden: semestres numéricos de menor a mayor; null (sin mapeo) al final
      semestres.sort((a, b) => {
        const sa = a.semestre_pensum, sb = b.semestre_pensum;
        if (sa == null && sb == null) return 0;
        if (sa == null) return 1;
        if (sb == null) return -1;
        return sa - sb;
      });

      // Render
      let html = "";
      if (semestres.length === 0) {
        html += `<p>No se encontraron notas registradas.</p>`;
        html += renderPromedioCard(promedio); // promedio al final incluso en este caso
      } else {
        for (const sem of semestres) {
          html += renderSemesterCard(sem);
        }
        html += renderPromedioCard(promedio); // promedio al final
      }
      cont.innerHTML = html;

    } catch (err) {
      console.error(err);
      cont.innerHTML = `<p class="error">Error de conexión al cargar las notas.</p>`;
    }
  }

  /* ============================== RENDER ============================== */
  function renderPromedioCard(promedio) {
    const val = (promedio == null) ? "—" : String(promedio);
    return `
      <div class="semester-card" aria-label="Promedio general">
        <h3>Promedio General</h3>
        <div class="grade-item">
          <span>Total</span>
          <span class="grade">${escapeHTML(val)}</span>
        </div>
      </div>
    `;
  }

  function renderSemesterCard(semData) {
    const sem = semData.semestre_pensum;
    const titulo = (sem == null)
      ? "Sin semestre (no mapeado)"
      : `${formatSemestreOrdinal(sem)} Semestre`;

    // Para cada materia, calculamos una única nota:
    // tomamos la oferta más reciente (id_oferta_materia mayor) y promediamos sus parciales (valor_final)
    const materias = Array.isArray(semData.materias) ? semData.materias.slice() : [];
    materias.sort((a, b) => (a.sigla || "").localeCompare(b.sigla || "", "es"));

    const filas = materias.map(m => {
      const nota = calcularNotaMateria(m);
      const etiqueta = m.sigla || m.codigo || "Materia";
      const notaTxt = (nota == null) ? "—" : String(Math.round(nota));
      return `
        <div class="grade-item">
          <span>${escapeHTML(etiqueta)}</span>
          <span class="grade">${escapeHTML(notaTxt)}</span>
        </div>
      `;
    }).join("");

    return `
      <div class="semester-card">
        <h3>${escapeHTML(titulo)}</h3>
        ${filas || `<div class="grade-item"><span>Sin materias</span><span class="grade">—</span></div>`}
      </div>
    `;
  }

  /* ============================ CÁLCULOS ============================= */
  function calcularNotaMateria(materia) {
    const ofertas = Array.isArray(materia.ofertas) ? materia.ofertas : [];
    if (ofertas.length === 0) return null;

    // Escogemos la oferta más reciente por id_oferta_materia
    let best = ofertas[0];
    for (let i = 1; i < ofertas.length; i++) {
      if ((ofertas[i].id_oferta_materia || 0) > (best.id_oferta_materia || 0)) {
        best = ofertas[i];
      }
    }

    const notas = Array.isArray(best.notas) ? best.notas : [];
    const valores = notas
      .map(n => (n && typeof n.valor_final === "number") ? n.valor_final : null)
      .filter(v => v != null && Number.isFinite(v));

    if (valores.length === 0) return null;

    const suma = valores.reduce((acc, v) => acc + v, 0);
    return suma / valores.length; // promedio simple de parciales de la última oferta
  }

  /* ============================== HELPERS ============================ */
  function escapeHTML(str) {
    return String(str ?? "").replace(/[&<>"']/g, s => ({
      "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"
    }[s]));
  }

  function formatSemestreOrdinal(n) {
    const x = Number.parseInt(n, 10);
    if (!Number.isFinite(x)) return "—";
    if (x === 1) return "1er";
    if (x === 2) return "2do";
    if (x === 3) return "3er";
    return `${x}to`;
  }
})();