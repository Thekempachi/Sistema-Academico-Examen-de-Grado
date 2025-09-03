// URL de la API en Hostinger
	const API_BASE = "https://im-ventas-de-computadoras.com/Sistema_Academico/";

	// 1. Obtener email del docente desde localStorage
	const docenteEmail = localStorage.getItem("docente_email");
	if (!docenteEmail) {
		window.location.href = "login.html";
	}

	// Cerrar sesión: limpiar datos del docente y volver al login
	const logoutBtn = document.getElementById("logout-btn");
	if (logoutBtn) {
		logoutBtn.addEventListener("click", () => {
			try {
				localStorage.removeItem("docente_email");
				localStorage.removeItem("docente_nombre");
				localStorage.removeItem("docente_apellido");
				localStorage.removeItem("docente_id");
			} catch (e) { /* ignore */ }
			window.location.href = "login.html";
		});
	}

	// 2. Consultar materias asignadas
	let materiasDocente = [];
	// Leer id_docente de localStorage al cargar la página
	let docenteId = localStorage.getItem("docente_id") || '';
	// const debugDiv = document.getElementById("debug");
	// debugDiv.innerHTML = `<b>Email usado:</b> ${docenteEmail}<br><b>id_docente localStorage:</b> ${docenteId}`;
	fetch(API_BASE + "get_materias_docente.php?email=" + encodeURIComponent(docenteEmail))
		.then(async r => {
			const text = await r.text();
			// debugDiv.innerHTML += `<br><b>Respuesta cruda API:</b><br><pre style='background:#f4f4f4;padding:8px;border-radius:6px;'>${text.replace(/</g,'&lt;')}</pre>`;
			let data;
			try { data = JSON.parse(text); } catch { data = {}; }
			const ul = document.getElementById("materias-list");
			if (!data.ok || !data.materias || data.materias.length === 0) {
				ul.innerHTML = "<li style='color:#b00;font-weight:500;'>No tienes materias asignadas.</li>";
				document.getElementById("docente-nombre").textContent = `Bienvenido, Docente`;
				return;
			}
			document.getElementById("docente-nombre").textContent = `Bienvenido, ${data.docente.nombre} ${data.docente.apellido}`;
			ul.innerHTML = "";
			materiasDocente = data.materias;
			// Si el id_docente no estaba en localStorage, lo asignamos ahora
			if (!docenteId) {
				if (data.materias.length > 0 && data.materias[0].id_docente) {
					docenteId = data.materias[0].id_docente;
					localStorage.setItem("docente_id", docenteId);
				} else if (data.docente && data.docente.id_docente) {
					docenteId = data.docente.id_docente;
					localStorage.setItem("docente_id", docenteId);
				}
			}
			data.materias.forEach((m, idx) => {
				const li = document.createElement("li");
				li.innerHTML = `<div><b>${m.nombre}</b> <span style='color:#2a4d8f;'>(Código: ${m.codigo})</span> Grupo: <b>${m.grupo}</b></div><button data-idx='${idx}' class='btn-ver-estudiantes'>Ver estudiantes</button>`;
				ul.appendChild(li);
			});
		});

	// 3. Ver estudiantes de una materia
	// Delegación de eventos para los botones "Ver estudiantes"
	document.getElementById("materias-list").addEventListener("click", function(e) {
		if (e.target.classList.contains("btn-ver-estudiantes")) {
			const idx = e.target.getAttribute("data-idx");
			cargarEstudiantesMateria(idx);
		}
	});


	function cargarEstudiantesMateria(idx) {
		const materia = materiasDocente[idx];
		document.getElementById("materias-list").style.display = "none";
		document.getElementById("estudiantes-section").style.display = "block";
		document.getElementById("materia-titulo").textContent = `Estudiantes de ${materia.nombre} (${materia.codigo})`;
		// Detectar el nombre correcto del campo id de la materia
		let idOferta = materia.id_Oferta_Materia || materia.id_oferta_materia || materia.idOfertaMateria || '';
		const inputAsistencia = document.getElementById("id_Oferta_Materia_asistencia");
		const inputNota = document.getElementById("id_Oferta_Materia_nota");
		if (idOferta) {
			if (inputAsistencia) inputAsistencia.value = idOferta;
			if (inputNota) inputNota.value = idOferta;
		} else {
			if (inputAsistencia) inputAsistencia.value = '';
			if (inputNota) inputNota.value = '';
		}
		if (materia.estudiantes && materia.estudiantes.length > 0) {
			renderAsistencia(materia.estudiantes);
			renderNotas(materia.estudiantes);
			// Precargar notas actuales para esta oferta
			prefetchNotas(idOferta, materia.estudiantes);
		} else {
			fetch(API_BASE + "get_materias_docente.php?email=" + encodeURIComponent(docenteEmail))
				.then(r => r.json())
				.then(data => {
					if (data.ok && data.materias[idx] && data.materias[idx].estudiantes) {
						renderAsistencia(data.materias[idx].estudiantes);
						renderNotas(data.materias[idx].estudiantes);
						prefetchNotas(idOferta, data.materias[idx].estudiantes);
					} else {
						renderAsistencia([]);
						renderNotas([]);
					}
				});
		}
	}


	// Genera planilla de asistencia para 30 días (puedes ajustar fechas dinámicamente)
	function renderAsistencia(estudiantes) {
		const tbody = document.querySelector("#asistencia-table tbody");
		tbody.innerHTML = "";
		if (!estudiantes || estudiantes.length === 0) {
			tbody.innerHTML = `<tr><td colspan='3'>No hay estudiantes inscritos.</td></tr>`;
		} else {
			estudiantes.forEach(e => {
				tbody.innerHTML += `
					<tr>
						<td>${e.nombre} ${e.apellido}</td>
						<td>${e.nro_registro}</td>
						<td style="text-align:center;">
						<input type="checkbox" name="asistencia" value="${e.id_Estudiante || e.id_estudiante || e.id || ''}">
						</td>
					</tr>
				`;
			});
		}
	}

	function renderNotas(estudiantes) {
		const tbody = document.querySelector("#notas-table tbody");
		tbody.innerHTML = "";
			if (!estudiantes || estudiantes.length === 0) {
				tbody.innerHTML = `<tr><td colspan='3'>No hay estudiantes inscritos.</td></tr>`;
			} else {
				estudiantes.forEach(e => {
					// Creamos input con data attrs para poder precargar y corregir
					const safeReg = String(e.nro_registro || '').replace(/[^\w-]/g,'_');
					tbody.innerHTML += `
						<tr>
							<td>${e.nombre} ${e.apellido}</td>
							<td>${e.nro_registro}</td>
							<td>
								<input
									id="nota_${safeReg}"
									data-nro-registro="${e.nro_registro}"
									data-id-estudiante="${e.id_Estudiante || ''}"
									data-id-nota-parcial=""
									data-valor-actual=""
									type="number" name="nota_${e.id_Estudiante}"
									style="width:60px;" min="0" max="100" step="1"
								>
							</td>
						</tr>
					`;
				});
			}
	}

	function cerrarEstudiantes() {
		document.getElementById("estudiantes-section").style.display = "none";
		document.getElementById("materias-list").style.display = "block";
		document.getElementById("mensaje").innerHTML = "";
	}


	// Utilidad: precargar notas actuales por oferta y estudiante
	async function prefetchNotas(idOferta, estudiantes) {
		if (!idOferta || !estudiantes || estudiantes.length === 0) return;
		const requests = estudiantes.map(async (e) => {
			const reg = e.nro_registro;
			if (!reg) return;
			try {
				const r = await fetch(API_BASE + "notas_estudiante.php?nro_registro=" + encodeURIComponent(reg));
				const text = await r.text();
				let data; try { data = JSON.parse(text); } catch { data = null; }
				if (!data || !data.ok || !data.semestres) return;
				// Buscar notas de esta oferta
				let idNota = null; let valor = null;
				for (const sem of data.semestres) {
					for (const mat of (sem.materias || [])) {
						for (const ofe of (mat.ofertas || [])) {
							if (Number(ofe.id_oferta_materia) === Number(idOferta)) {
								const notas = ofe.notas || [];
								if (notas.length > 0) {
									const last = notas[notas.length - 1];
									idNota = last.id_nota_parcial || null;
									valor = (last.valor_final !== null && last.valor_final !== undefined) ? last.valor_final : last.valor_original;
								}
							}
						}
					}
				}
				// Actualizar UI si encontramos
				const safeId = 'nota_' + String(reg).replace(/[^\w-]/g,'_');
				const input = document.getElementById(safeId);
				if (input) {
					if (valor !== null && valor !== undefined) {
						input.value = valor;
						input.setAttribute('data-valor-actual', String(valor));
					}
					if (idNota) {
						input.setAttribute('data-id-nota-parcial', String(idNota));
					}
				}
			} catch (e) {
				// Ignorar errores por alumno individual
			}
		});
		await Promise.allSettled(requests);
	}

	// Guardar asistencia (planilla)

	document.getElementById("asistencia-form").addEventListener("submit", function(e) {
		e.preventDefault();
		const form = e.target;
		let errores = 0;
		const checkboxes = form.querySelectorAll("input[type='checkbox'][name='asistencia']:checked");
		const id_Oferta_Materia = document.getElementById("id_Oferta_Materia_asistencia").value;
		// Fecha local YYYY-MM-DD (sin hora, evita desfases por UTC)
		const now = new Date();
		const hoy = `${now.getFullYear()}-${String(now.getMonth()+1).padStart(2,'0')}-${String(now.getDate()).padStart(2,'0')}`;
		let enviados = 0;
		let debugLog = '';
		if (form.querySelectorAll("input[type='checkbox'][name='asistencia']").length === 0) {
			document.getElementById("mensaje").innerHTML = '<div style="color:red">No hay estudiantes para registrar asistencia.</div>';
			return;
		}
		checkboxes.forEach(cb => {
			const id_Estudiante = cb.value;
			const payload = {
				id_Estudiante,
				id_Oferta_Materia,
				fecha: hoy
			};
			fetch(API_BASE + "asignar_asistencia.php", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify(payload)
			})
			.then(async r => {
				// Manejo robusto: algunos servidores devuelven cuerpo vacío o texto simple
				const statusOk = r.ok;
				const status = r.status;
				const statusText = r.statusText;
				const text = await r.text();
				let resp;
				try {
					resp = text ? JSON.parse(text) : { ok: statusOk };
				} catch (e) {
					const t = (text || '').trim().toLowerCase();
					const looksOk = statusOk || t === 'ok' || t === '1' || t === 'true' || t === 'success';
					resp = { ok: looksOk, raw: text };
				}
				debugLog += `<pre style='background:#f4f4f4;padding:6px;border-radius:5px;'>URL: ${API_BASE + 'asignar_asistencia.php'}\nHTTP: ${status} ${statusText}\nRespuesta cruda: ${text ? text.replace(/</g,'&lt;') : '(vacía)'}\nInterpretado: ${JSON.stringify(resp, null, 2)}</pre>`;
				// Tratar duplicados como idempotente (ya registrada)
				if (!resp.ok) {
					const dup = (resp && resp.error === 'PROC_ASISTENCIA' && /duplicate entry/i.test(resp.msg || ''));
					if (!dup) errores++;
				}
				enviados++;
				if (enviados === checkboxes.length) {
					mostrarMensajeAsistencia(errores);
				}
			})
			.catch(err => {
				debugLog += `<pre style='background:#f4f4f4;padding:6px;border-radius:5px;'>Error: ${err}</pre>`;
				errores++;
				enviados++;
				if (enviados === checkboxes.length) {
					mostrarMensajeAsistencia(errores);
				}
			});
		});
		// Si nadie fue marcado como presente
		if (checkboxes.length === 0) {
			document.getElementById("mensaje").innerHTML = '<div style="color:orange">No se marcó asistencia para ningún estudiante.</div>';
		}
	});

	function mostrarMensajeAsistencia(errores) {
		if (errores === 0) {
			document.getElementById("mensaje").innerHTML = '<div style="color:green">Asistencia guardada correctamente.</div>';
		} else {
			document.getElementById("mensaje").innerHTML = '<div style="color:red">Error al guardar algunas asistencias.</div>';
		}
	}

	// Guardar notas (formulario separado)

	document.getElementById("notas-form").addEventListener("submit", function(e) {
		e.preventDefault();
		const id_Oferta_Materia = document.getElementById("id_Oferta_Materia_nota") ? document.getElementById("id_Oferta_Materia_nota").value : '';
		const id_Docente = docenteId || '';
		const rows = document.querySelectorAll("#notas-table tbody tr");
		let resultados = [];
		let errores = 0;
		let debugLog = '';

		const done = () => {
			if (resultados.length === rows.length) {
				if (errores === 0) {
					document.getElementById("mensaje").innerHTML = '<div style="color:green">Notas guardadas correctamente.</div>';
				} else {
					document.getElementById("mensaje").innerHTML = '<div style="color:red">Error al guardar algunas notas.</div>';
				}
			}
		};

		rows.forEach(row => {
			const input = row.querySelector('input');
			const nro_registro = row.children[1].textContent.trim();
			const idNotaParcial = input.getAttribute('data-id-nota-parcial');
			const valorActualStr = input.getAttribute('data-valor-actual');
			const valorActual = (valorActualStr !== null && valorActualStr !== '') ? Number(valorActualStr) : null;
			let nota = input.value;
			nota = nota !== '' ? Number(nota) : '';

			// Si no hay cambio y ya existe nota, contar como OK sin llamar API
			if (idNotaParcial && nota !== '' && valorActual !== null && Number(nota) === Number(valorActual)) {
				const localMsg = { ok:true, msg:'sin cambios' };
				resultados.push({ nro_registro, resp: localMsg });
				return done();
			}

			// Si hay idNotaParcial => corregir; si no hay y hay valor => insertar
			if (idNotaParcial && nota !== '') {
				const payload = { id_Nota_Parcial: Number(idNotaParcial), valor_nuevo: Number(nota), motivo: '' };
				const url = API_BASE + "corregir_nota.php";
				console.log('Corrección nota ->', url, payload);
				fetch(API_BASE + "corregir_nota.php", {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify(payload)
				})
				.then(async r => {
					const status = r.status; const statusText = r.statusText;
					const text = await r.text();
					let resp; try { resp = text ? JSON.parse(text) : { ok:r.ok }; } catch { resp = { ok:false, raw:text }; }
					const okFlag = resp.ok || resp.status === 'VALOR_CAMBIADO_CONCURRENTE';
					resultados.push({nro_registro, resp});
					if (!okFlag) errores++;
					else {
						// Actualizar dataset con nuevo valor
						input.setAttribute('data-valor-actual', String(nota));
					}
					debugLog += `<pre style='background:#f5fff1;padding:6px;border-radius:5px;'>HTTP: ${status} ${statusText}\nRESPUESTA: ${text ? text.replace(/</g,'&lt;') : '(vacía)'}\nPARSE: ${JSON.stringify(resp)}</pre>`;
					done();
				})
				.catch((err) => {
					resultados.push({nro_registro, resp:'error'});
					errores++;
					debugLog += `<pre style='background:#ffecec;padding:6px;border-radius:5px;'>ERROR FETCH corregir: ${String(err)}</pre>`;
					done();
				});
			} else if (!idNotaParcial && nota !== '') {
				const payload = { nro_registro, id_Oferta_Materia, valor: Number(nota), id_Docente };
				const url = API_BASE + "asignar_nota.php";
				debugLog += `<pre style='background:#eef6ff;padding:6px;border-radius:5px;'>ACCION: insertar\nURL: ${url}\nPAYLOAD: ${JSON.stringify(payload)}</pre>`;
				console.log('Insertar nota ->', url, payload);
				fetch(API_BASE + "asignar_nota.php", {
					method: "POST",
					headers: { "Content-Type": "application/json" },
					body: JSON.stringify(payload)
				})
				.then(async r => {
					const status = r.status; const statusText = r.statusText;
					const text = await r.text();
					let resp; try { resp = text ? JSON.parse(text) : { ok:r.ok }; } catch { resp = { ok:false, raw:text }; }
					resultados.push({nro_registro, resp});
					if (!resp.ok) errores++;
					else {
						if (resp.id_nota) input.setAttribute('data-id-nota-parcial', String(resp.id_nota));
						input.setAttribute('data-valor-actual', String(nota));
					}
					debugLog += `<pre style='background:#f5fff1;padding:6px;border-radius:5px;'>HTTP: ${status} ${statusText}\nRESPUESTA: ${text ? text.replace(/</g,'&lt;') : '(vacía)'}\nPARSE: ${JSON.stringify(resp)}</pre>`;
					done();
				})
				.catch((err) => {
					resultados.push({nro_registro, resp:'error'});
					errores++;
					debugLog += `<pre style='background:#ffecec;padding:6px;border-radius:5px;'>ERROR FETCH insertar: ${String(err)}</pre>`;
					done();
				});
			} else {
				// Sin valor ingresado: no hacemos nada
				const localMsg = {ok:true, msg:'sin valor'};
				resultados.push({nro_registro, resp:localMsg});
				debugLog += `<pre style='background:#f4f4f4;padding:6px;border-radius:5px;'>ACCION: sin valor\nREGISTRO: ${nro_registro}</pre>`;
				done();
			}
		});
		return;

	});