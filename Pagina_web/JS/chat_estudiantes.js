// Pagina_web/JS/chat_estudiantes.js
// Chatbot UI + cliente para el endpoint PHP

(function () {
  const ENDPOINT = "https://im-ventas-de-computadoras.com/Sistema_Academico/chat_estudiante.php"; // URL pública del servidor

  // Permite definir instrucciones desde la página (antes de cargar este script)
  let ADMIN_INSTRUCTIONS = (typeof window !== 'undefined' && window.CHAT_INSTRUCCIONES) ? String(window.CHAT_INSTRUCCIONES) : '';

  // Utilidad para actualizar instrucciones dinámicamente desde consola o UI
  window.setChatInstructions = function (text) {
    ADMIN_INSTRUCTIONS = String(text || '');
    // reiniciar conversación si cambia la política (opcional)
    clearHistory();
    appendBotMessage("He actualizado mis instrucciones. ¿En qué puedo ayudarte?");
    openPanel();
  };

  // Estado de conversación (limitado y persistido en sessionStorage)
  const STORAGE_KEY = 'chat_estudiante_hist';
  function loadHistory() {
    try {
      const raw = sessionStorage.getItem(STORAGE_KEY);
      if (!raw) return [];
      const arr = JSON.parse(raw);
      return Array.isArray(arr) ? arr : [];
    } catch (_) {
      return [];
    }
  }
  function saveHistory(hist) {
    try { sessionStorage.setItem(STORAGE_KEY, JSON.stringify(hist)); } catch (_) {}
  }
  function clearHistory() {
    try { sessionStorage.removeItem(STORAGE_KEY); } catch (_) {}
    history = [];
    const list = document.getElementById('chat_messages');
    if (list) list.innerHTML = '';
  }

  let history = loadHistory(); // [{role:'user'|'assistant', content: '...'}]

  // Inyectar estilos del chat (aislado)
  const styles = `
  .chat-fab { position: fixed; bottom: 24px; right: 24px; width: 56px; height: 56px; border-radius: 50%; background: #1e3a8a; color: #fff; border: none; box-shadow: 0 6px 18px rgba(0,0,0,0.2); cursor: pointer; z-index: 1100; display: flex; align-items: center; justify-content: center; font-size: 22px; }
  .chat-fab:hover { background: #3b82f6; }
  .chat-panel { position: fixed; bottom: 96px; right: 24px; width: 360px; max-width: calc(100vw - 32px); height: 70vh; max-height: 640px; background: #fff; border-radius: 12px; box-shadow: 0 12px 30px rgba(0,0,0,0.25); display: none; flex-direction: column; overflow: hidden; z-index: 1100; border: 1px solid #e5e7eb; }
  .chat-header { background: linear-gradient(135deg, #1e3a8a, #3b82f6); color: #fff; padding: 10px 12px; display: flex; align-items: center; justify-content: space-between; }
  .chat-title { display: flex; align-items: center; gap: 8px; font-weight: 600; }
  .chat-actions { display: flex; gap: 6px; }
  .chat-actions button { background: transparent; border: none; color: #fff; cursor: pointer; font-size: 16px; opacity: .9; }
  .chat-actions button:hover { opacity: 1; }
  .chat-body { flex: 1; padding: 12px; background: #f8fafc; overflow-y: auto; }
  .chat-msg { display: flex; margin-bottom: 10px; }
  .chat-msg.user { justify-content: flex-end; }
  .chat-bubble { max-width: 78%; padding: 10px 12px; border-radius: 10px; box-shadow: 0 2px 6px rgba(0,0,0,0.08); white-space: pre-wrap; }
  .chat-msg.user .chat-bubble { background: #1e3a8a; color: #fff; border-bottom-right-radius: 4px; }
  .chat-msg.bot .chat-bubble { background: #fff; color: #0f172a; border: 1px solid #e5e7eb; border-bottom-left-radius: 4px; }
  .chat-footer { padding: 10px; background: #fff; border-top: 1px solid #e5e7eb; }
  .chat-input { display: flex; gap: 8px; }
  .chat-input textarea { flex: 1; resize: none; max-height: 120px; min-height: 42px; padding: 10px; border: 1px solid #e5e7eb; border-radius: 8px; outline: none; }
  .chat-input textarea:focus { border-color: #1e3a8a; box-shadow: 0 0 0 3px rgba(30,58,138,0.1); }
  .chat-send { background: #1e3a8a; color: #fff; border: none; padding: 0 14px; border-radius: 8px; cursor: pointer; }
  .chat-send:disabled { opacity: .6; cursor: not-allowed; }
  .chat-hint { font-size: 12px; color: #64748b; margin-top: 6px; display: flex; justify-content: space-between; }
  .chat-typing { font-size: 12px; color: #64748b; margin: 6px 0 0 4px; }
  .chat-suggestions { display: flex; gap: 6px; flex-wrap: wrap; margin-bottom: 8px; }
  .chat-suggestions button { background: #eef2ff; color: #1e3a8a; border: 1px solid #c7d2fe; padding: 6px 10px; border-radius: 999px; cursor: pointer; font-size: 12px; }
  .chat-suggestions button:hover { background: #e0e7ff; }
  `;
  const styleTag = document.createElement('style');
  styleTag.textContent = styles;
  document.head.appendChild(styleTag);

  // Construir UI
  const fab = document.createElement('button');
  fab.className = 'chat-fab';
  fab.title = 'Asistente para estudiantes';
  fab.setAttribute('aria-label', 'Abrir chat de asistencia');
  fab.innerHTML = '<i class="fas fa-comments"></i>';

  const panel = document.createElement('div');
  panel.className = 'chat-panel';
  panel.innerHTML = `
    <div class="chat-header">
      <div class="chat-title"><i class="fas fa-graduation-cap"></i> Asistente UNB</div>
      <div class="chat-actions">
        <button id="chat_clear" title="Nueva conversación"><i class="fas fa-rotate-right"></i></button>
        <button id="chat_close" title="Cerrar"><i class="fas fa-times"></i></button>
      </div>
    </div>
    <div class="chat-body">
      <div class="chat-suggestions" id="chat_suggestions"></div>
      <div id="chat_messages" aria-live="polite" aria-label="Mensajes del chat"></div>
      <div id="chat_typing" class="chat-typing" style="display:none;">Escribiendo…</div>
    </div>
    <div class="chat-footer">
      <form id="chat_form" class="chat-input">
        <textarea id="chat_input" placeholder="Escribe tu consulta (ej. horarios, notas, pensum)…" rows="1"></textarea>
        <button id="chat_send" class="chat-send" type="submit"><i class="fas fa-paper-plane"></i></button>
      </form>
      <div class="chat-hint">
        <span>Respuestas orientativas. Verifica en tu portal.</span>
        <a href="#" id="chat_cfg" title="Cambiar instrucciones" style="text-decoration: underline;">Configurar</a>
      </div>
    </div>
  `;

  document.body.appendChild(fab);
  document.body.appendChild(panel);

  const chatMessages = panel.querySelector('#chat_messages');
  const chatForm = panel.querySelector('#chat_form');
  const chatInput = panel.querySelector('#chat_input');
  const chatSend = panel.querySelector('#chat_send');
  const chatTyping = panel.querySelector('#chat_typing');
  const chatClose = panel.querySelector('#chat_close');
  const chatClear = panel.querySelector('#chat_clear');
  const chatCfg = panel.querySelector('#chat_cfg');
  const chatSuggestions = panel.querySelector('#chat_suggestions');

  function openPanel() { panel.style.display = 'flex'; setTimeout(() => chatInput.focus(), 50); }
  function closePanel() { panel.style.display = 'none'; }

  fab.addEventListener('click', openPanel);
  chatClose.addEventListener('click', (e) => { e.preventDefault(); closePanel(); });
  chatClear.addEventListener('click', (e) => { e.preventDefault(); clearHistory(); appendWelcome(); });

  chatCfg.addEventListener('click', (e) => {
    e.preventDefault();
    const current = ADMIN_INSTRUCTIONS || '';
    const updated = prompt('Instrucciones para el asistente (administrador):', current);
    if (updated !== null) {
      window.setChatInstructions(updated);
    }
  });

  function appendWelcome() {
    appendBotMessage('¡Hola! Soy tu asistente académico. Puedo ayudarte con materias, notas, pensum, calendarios, requisitos y trámites. ¿Qué necesitas?');
    renderSuggestions();
  }

  function renderSuggestions() {
    chatSuggestions.innerHTML = '';
    const items = [
      '¿Qué materias puedo inscribir?',
      'Ver mis notas del semestre',
      'Requisitos para titulación',
      'Calendario académico',
      'Contacto de mi carrera'
    ];
    for (const t of items) {
      const b = document.createElement('button');
      b.type = 'button';
      b.textContent = t;
      b.addEventListener('click', () => {
        chatInput.value = t;
        chatForm.dispatchEvent(new Event('submit', { cancelable: true }));
      });
      chatSuggestions.appendChild(b);
    }
  }

  function appendUserMessage(text) {
    const item = document.createElement('div');
    item.className = 'chat-msg user';
    item.innerHTML = `<div class="chat-bubble">${escapeHtml(text)}</div>`;
    chatMessages.appendChild(item);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }
  function appendBotMessage(text) {
    const item = document.createElement('div');
    item.className = 'chat-msg bot';
    item.innerHTML = `<div class="chat-bubble">${escapeHtml(text)}</div>`;
    chatMessages.appendChild(item);
    chatMessages.scrollTop = chatMessages.scrollHeight;
  }
  function setTyping(on) { chatTyping.style.display = on ? 'block' : 'none'; }

  function escapeHtml(str) {
    return String(str)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  }

  chatForm.addEventListener('submit', async (e) => {
    e.preventDefault();
    const text = chatInput.value.trim();
    if (!text) return;
    chatInput.value = '';
    chatSend.disabled = true;
    appendUserMessage(text);

    // Actualizar historial y limitar tamaño
    history.push({ role: 'user', content: text });
    if (history.length > 24) history = history.slice(-24);
    saveHistory(history);

    setTyping(true);
    try {
      const payload = {
        message: text,
        history: history.slice(-12),
        instructions: ADMIN_INSTRUCTIONS || '',
        student: {
          nro_registro: sessionStorage.getItem('nro_registro_estudiante') || ''
        }
      };
      const res = await fetch(ENDPOINT, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (!res.ok) {
        const err = await res.json().catch(() => ({}));
        throw new Error(err.error || `Error ${res.status}`);
      }
      const data = await res.json();
      const reply = (data && data.reply) ? String(data.reply) : 'No pude generar respuesta.';
      appendBotMessage(reply);
      history.push({ role: 'assistant', content: reply });
      if (history.length > 24) history = history.slice(-24);
      saveHistory(history);
    } catch (err) {
      appendBotMessage('Lo siento, hubo un problema al responder. Intenta nuevamente más tarde.');
      console.error(err);
    } finally {
      setTyping(false);
      chatSend.disabled = false;
    }
  });

  // Render inicial
  if (history.length === 0) {
    appendWelcome();
  } else {
    // Rehidratar mensajes previos
    for (const m of history) {
      if (m.role === 'user') appendUserMessage(m.content);
      if (m.role === 'assistant') appendBotMessage(m.content);
    }
  }
})();
