// script_pensum_estudiante.js
(() => {
  // Endpoints privados del módulo
  const ENDPOINT_PENSUM   = "https://im-ventas-de-computadoras.com/Sistema_Academico/pensum_estudiante.php";
  const ENDPOINT_MATERIAS_PENSUM = "https://im-ventas-de-computadoras.com/Sistema_Academico/materias_estudiante.php";

  document.addEventListener("DOMContentLoaded", () => {
    pintarBienvenidaDesdeSession();
    cargarPensumEstudiante();
  });

  /* ========================= UTILIDADES DE ESTADO ========================= */
  function getStore(key) {
    return sessionStorage.getItem(key) || localStorage.getItem(key) || "";
  }
  function getNR() {
    return getStore("nro_registro_estudiante");
  }
  function getNombreCompleto() {
    const n = getStore("nombre_estudiante");
    const a = getStore("apellido_estudiante");
    const full = `${n || ""} ${a || ""}`.trim();
    return full || "Estudiante";
  }
  function pintarBienvenidaDesdeSession() {
    const el = document.getElementById("alumno-nombre");
    if (el) el.textContent = getNombreCompleto();
  }

  /* ======================= CARGA Y RENDER DEL PENSUM ====================== */
  async function cargarPensumEstudiante() {
    const cont = document.getElementById("pensum-container");
    if (!cont) return;

    const nro_registro = getNR();
    if (!nro_registro) {
      cont.innerHTML = `<p class="error">No se encontró el Nro. de registro en esta sesión. Inicie sesión nuevamente.</p>`;
      return;
    }

    cont.innerHTML = `<p>Cargando pensum...</p>`;

    try {
      const body = new URLSearchParams({ nro_registro });
      const resp = await fetch(ENDPOINT_PENSUM, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body
      });

      const raw = await resp.text();
      let data;
      try { data = JSON.parse(raw); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw }; }

      if (!resp.ok || !data.ok) {
        const msg = data.msg || data.error || `HTTP ${resp.status}`;
        cont.innerHTML = `<p class="error">No se pudo cargar el pensum. ${escapeHTML(String(msg))}</p>`;
        console.error("pensum_estudiante.php respuesta:", raw);
        return;
      }

      const pensum = Array.isArray(data.pensum) ? data.pensum : [];
      if (pensum.length === 0) {
        cont.innerHTML = `<p>No se encontraron materias en el pensum activo de tu plan de estudio.</p>`;
        return;
      }

      const grupos = agruparPorSemestre(pensum);

      // (Opcional) inferir semestre actual
      let semestreActual = null;
      try {
        semestreActual = await inferirSemestreActualDesdeMaterias(grupos);
      } catch (e) {
        console.warn("No se pudo inferir el semestre actual desde materias:", e);
      }

      const titleEl = document.getElementById("pensum-title");
      if (titleEl && semestreActual != null) {
        titleEl.textContent = `Pensum — ${formatSemestreOrdinal(semestreActual)} Semestre`;
      }

      cont.innerHTML = renderPensumPorSemestre(grupos, semestreActual);

    } catch (err) {
      console.error(err);
      cont.innerHTML = `<p class="error">Error de conexión al cargar el pensum.</p>`;
    }
  }

  /* ============================= LÓGICA AUX =============================== */
  function agruparPorSemestre(pensum) {
    const map = new Map();
    for (const it of pensum) {
      const s = toIntSafe(it.semestre_pensum, 0);
      if (!map.has(s)) map.set(s, []);
      map.get(s).push(it);
    }
    for (const [k, arr] of map.entries()) {
      arr.sort((a, b) => (a.sigla || "").localeCompare(b.sigla || "", "es"));
    }
    return new Map([...map.entries()].sort((a, b) => a[0] - b[0]));
  }

  async function inferirSemestreActualDesdeMaterias(grupos) {
    const nro_registro = getNR();
    if (!nro_registro) return null;

    const body = new URLSearchParams({ nro_registro });
    const resp = await fetch(ENDPOINT_MATERIAS_PENSUM, {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body
    });
    const raw = await resp.text();
    let data;
    try { data = JSON.parse(raw); } catch { data = { ok:false, error:"RESP_JSON_INVALIDA", raw }; }

    if (!resp.ok || !data.ok) return null;
    const items = Array.isArray(data.items) ? data.items : [];
    if (items.length === 0) return null;

    const siglaToSem = new Map();
    for (const [, arr] of grupos.entries()) {
      for (const m of arr) {
        const sig = (m.sigla || "").trim().toUpperCase();
        if (sig) siglaToSem.set(sig, toIntSafe(m.semestre_pensum, null));
      }
    }

    const semestres = [];
    for (const it of items) {
      const sig = (safe(it, "materia.sigla") || "").trim().toUpperCase();
      const sem = siglaToSem.get(sig);
      if (sem != null) semestres.push(sem);
    }
    if (semestres.length === 0) return null;

    const moda = modaNumerica(semestres);
    const max  = Math.max(...semestres);
    return moda ?? max;
  }

  /* =============================== RENDER ================================= */
  function renderPensumPorSemestre(grupos, semestreActual) {
    let html = "";
    for (const [sem, materias] of grupos.entries()) {
      const titulo = `${formatSemestreOrdinal(sem)} Semestre${semestreActual === sem ? " (Actual)" : ""}`;
      const clase  = (semestreActual == null)
        ? "current-semester"
        : (sem === semestreActual ? "current-semester" : (sem > semestreActual ? "next-semester" : "current-semester"));

      html += `
        <div class="${clase}">
          <h3>${escapeHTML(titulo)}</h3>
          <ul class="subject-list">
            ${materias.map(m => `<li>${escapeHTML(m.sigla || m.codigo || "Materia")}</li>`).join("")}
          </ul>
        </div>
      `;
    }
    return html;
  }

  /* ============================== HELPERS ================================= */
  function safe(obj, path) {
    try { return path.split(".").reduce((o, k) => (o && k in o ? o[k] : undefined), obj); }
    catch { return undefined; }
  }
  function toIntSafe(v, fallback) {
    const n = Number.parseInt(v, 10);
    return Number.isFinite(n) ? n : fallback;
    }
  function escapeHTML(str) {
    return String(str ?? "").replace(/[&<>"']/g, s => ({
      "&":"&amp;","<":"&lt;",">":"&gt;","\"":"&quot;","'":"&#39;"
    }[s]));
  }
  function formatSemestreOrdinal(n) {
    const x = toIntSafe(n, null);
    if (x == null) return "—";
    if (x === 1) return "1er";
    if (x === 2) return "2do";
    if (x === 3) return "3er";
    return `${x}to`;
  }
  function modaNumerica(arr) {
    const cnt = new Map();
    for (const v of arr) cnt.set(v, (cnt.get(v) || 0) + 1);
    let best = null, bestC = 0;
    for (const [v, c] of cnt.entries()) {
      if (c > bestC || (c === bestC && v > best)) {
        best = v; bestC = c;
      }
    }
    return best;
  }
})();
