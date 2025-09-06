<?php
// Pagina_web/php/chat_estudiante.php
// Endpoint para el chatbot de estudiantes que usa la API de OpenAI

// CORS + JSON
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// Solo permitir POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Método no permitido']);
    exit;
}

// Obtener API Key desde variable de entorno por seguridad (fallback a clave provista)
$apiKey = getenv('OPENAI_API_KEY');
if (!$apiKey) {
    // ADVERTENCIA: Mantener claves en código no es recomendado. Úsalo sólo si no puedes configurar variables de entorno.
    $apiKey = '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';
}
if (!$apiKey) {
    http_response_code(500);
    echo json_encode([
        'error' => 'Falta la clave de API. Define la variable de entorno OPENAI_API_KEY en el servidor.'
    ]);
    exit;
}

// Leer body JSON
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
if (!is_array($data)) {
    http_response_code(400);
    echo json_encode(['error' => 'Cuerpo de la solicitud inválido']);
    exit;
}

$userMessage  = isset($data['message']) ? trim((string)$data['message']) : '';
$historyInput = isset($data['history']) && is_array($data['history']) ? $data['history'] : [];
$instructions = isset($data['instructions']) ? trim((string)$data['instructions']) : '';
// Datos del estudiante (opcionales) para habilitar consultas internas
$student = isset($data['student']) && is_array($data['student']) ? $data['student'] : [];
$nroRegistro = isset($student['nro_registro']) ? trim((string)$student['nro_registro']) : '';

if ($userMessage === '') {
    http_response_code(400);
    echo json_encode(['error' => 'Mensaje vacío']);
    exit;
}

// Prompt por defecto (puedes ajustar el tono y el alcance)
$defaultSystem = <<<EOT
Eres el Asistente Virtual Académico de la Universidad. Atiendes exclusivamente a estudiantes.

Reglas:
- Responde SIEMPRE en español, claro y respetuoso.
- Sé breve pero preciso. Lista pasos cuando sea útil.
- Si la pregunta no es del ámbito universitario (materias, notas, inscripciones, calendarios, trámites, contacto, horarios, requisitos), indícalo y ofrece derivar a soporte.
- Si te piden datos personales o cambios en el sistema, explica que no tienes acceso directo y guía el proceso.
- Si no tienes información suficiente, solicita los datos necesarios (carrera, semestre, materia, periodo, etc.).

Límites:
- No inventes datos. Si no conoces una política, di que no cuentas con ella y sugiere consultar la secretaría o el portal oficial.
- No des consejos legales/financieros.
EOT;

// Ampliar alcance: permitir preguntas generales tipo ChatGPT
$defaultSystem .= "\n\nPuedes responder preguntas generales fuera del ambito universitario (definiciones, que es, como funciona, significado, ejemplos, comparaciones).\n" .
                  "Cuando la consulta sea sobre el estudiante (notas, ofertas, pensum), fundamenta en los Datos verificables del sistema si existen.\n" .
                  "Si no hay datos verificados, dilo y responde de forma general sin inventar datos administrativos.";

if ($instructions !== '') {
    $defaultSystem .= "\n\nInstrucciones administrativas adicionales:\n" . $instructions;
}

// Sanitizar y compactar el historial recibido (opcional desde el cliente)
$messages = [ [ 'role' => 'system', 'content' => $defaultSystem ] ];

// Intento simple de detectar intención para enriquecer con datos del sistema
function detectar_intencion($texto) {
    $t = mb_strtolower($texto, 'UTF-8');
    // Notas
    if (preg_match('/\bnota(s)?\b|calificaci(ón|ones)/u', $t)) {
        return 'notas';
    }
    // Ofertas/inscripción
    if (preg_match('/oferta(s)?|inscri(bir|pción)|registrar( materias)?/u', $t)) {
        return 'ofertas';
    }
    // Pensum/malla
    if (preg_match('/pensum|malla|plan de estudios/u', $t)) {
        return 'pensum';
    }
    return 'general';
}

// --- Detección extendida con sinónimos y exclusión de inscripción/registro ---
function normalizar_es($s) {
    $s = mb_strtolower($s, 'UTF-8');
    if (class_exists('Transliterator')) {
        $tr = Transliterator::create('NFD; [:Nonspacing Mark:] Remove; NFC');
        if ($tr) { $s = $tr->transliterate($s); }
    } else {
        $tmp = @iconv('UTF-8','ASCII//TRANSLIT//IGNORE', $s);
        if ($tmp !== false) $s = $tmp;
    }
    $s = preg_replace('/[^\p{L}\p{N}\s]/u', ' ', $s);
    $s = preg_replace('/\s+/u', ' ', $s);
    return trim($s);
}

$INTENT_KEYWORDS = [
  'notas' => [
    'nota','notas','calificacion','calificaciones','promedio','promedios','media','valoracion','valoraciones',
    'resultado','resultados','kardex','historial academico','reporte de notas','boletin','transcripcion','gpa','indice academico'
  ],
  'ofertas' => [
    'oferta','ofertas','materia','materias','asignatura','asignaturas','curso','cursos','clase','clases',
    'grupo','grupos','paralelo','paralelos','seccion','secciones','cupo','cupos'
  ],
  'pensum'  => [
    'pensum','plan de estudio','plan de estudios','malla','malla curricular','curricula','curricular','curriculo',
    'mapa curricular','estructura curricular','reticula','programa academico','requisitos','prerequisitos','correlativas','creditos'
  ],
];

$INTENT_PATTERNS = [
  'notas' => [
    '/\bnota(?:s)?\b/u','/\bcalificaci(?:on|ones)\b/u','/\bpromedio(?:s)?\b/u','/\bhistorial\s+academico\b/u','/\bboletin(?:es)?\b/u','/\btranscripci(?:on|ones)\b/u','/\bkardex\b/u','/\b(gpa|indice\s+academico)\b/u'
  ],
  'ofertas' => [
    '/\boferta(?:s)?\b/u','/\bmateria(?:s)?\b/u','/\basignatura(?:s)?\b/u','/\bcurso(?:s)?\b/u','/\bclase(?:s)?\b/u','/\bgrupo(?:s)?\b/u','/\bparalel(?:o|os)\b/u','/\bseccion(?:es)?\b/u','/\bcupo(?:s)?\b/u'
  ],
  'pensum' => [
    '/\bpensum\b/u','/\bmalla(?:\s+curricular)?\b/u','/\bplan\s+de\s+estudio(?:s)?\b/u','/\bcurricul\w+/u','/\breticul\w+/u','/\bmapa\s+curricular\b/u','/\bestructura\s+curricular\b/u','/\bcredito(?:s)?\b/u'
  ],
];

function detectar_intencion_extendido($texto) {
    global $INTENT_KEYWORDS, $INTENT_PATTERNS;
    $t = normalizar_es((string)$texto);
    // Evitar que palabras de inscripcion/registro/matricula disparen ofertas
    if (preg_match('/\b(inscrib\w*|inscripci\w*|matricul\w*|registr\w*)\b/u', $t)) {
        // Permitir solo si claramente pide notas o pensum
        foreach (['notas','pensum'] as $cand) {
            foreach ($INTENT_PATTERNS[$cand] as $p) { if (preg_match($p, $t)) return $cand; }
        }
        return 'general';
    }
    foreach ($INTENT_PATTERNS as $intent => $patterns) {
        foreach ($patterns as $p) { if (preg_match($p, $t)) return $intent; }
    }
    foreach ($INTENT_KEYWORDS as $intent => $words) {
        $quoted = array_map(function($w){
            $w = normalizar_es($w);
            $w = preg_quote($w, '/');
            return str_replace(' ', '\\s+', $w);
        }, $words);
        $pattern = '/\\b(?:' . implode('|', $quoted) . ')\\b/u';
        if (preg_match($pattern, $t)) return $intent;
    }
    return 'general';
}

$intencion = detectar_intencion_extendido($userMessage);

// Contextos para fallback
$ctxNotas = null;   // ['promedio_final'=>?, 'semestres'=>[...] ]
$ctxOfertas = null; // [ {sigla,materia,grupo,docente,cupos}, ... ]
$ctxPensum = null;  // ['semestres'=> [ {semestre, materias:[{sigla,materia}]} ] ]

// Si la intención es "notas" y contamos con nro_registro, intentamos consultar al backend de notas
// para proporcionar contexto factual al modelo.
if ($intencion === 'notas' && $nroRegistro !== '') {
    $notasUrl = 'https://im-ventas-de-computadoras.com/Sistema_Academico/notas_estudiante.php?nro_registro=' . urlencode($nroRegistro);
    $chNotas = curl_init($notasUrl);
    curl_setopt($chNotas, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($chNotas, CURLOPT_TIMEOUT, 15);
    $respNotas = curl_exec($chNotas);
    $statusNotas = curl_getinfo($chNotas, CURLINFO_HTTP_CODE);
    curl_close($chNotas);
    if ($respNotas !== false && $statusNotas >= 200 && $statusNotas < 300) {
        $jsonNotas = json_decode($respNotas, true);
        if (is_array($jsonNotas) && isset($jsonNotas['ok']) && $jsonNotas['ok'] === true) {
            // Reducir datos para el prompt (evitar tamaño excesivo)
            $promedio = isset($jsonNotas['promedio_final']) ? $jsonNotas['promedio_final'] : null;
            $resumen = [ 'promedio_final' => $promedio, 'semestres' => [] ];
            if (isset($jsonNotas['semestres']) && is_array($jsonNotas['semestres'])) {
                $maxSem = 3; // limitar a 3 semestres más recientes
                $slice = array_slice($jsonNotas['semestres'], -$maxSem);
                foreach ($slice as $sem) {
                    $semOut = [
                        'semestre_pensum' => $sem['semestre_pensum'] ?? null,
                        'materias' => []
                    ];
                    if (isset($sem['materias']) && is_array($sem['materias'])) {
                        foreach ($sem['materias'] as $m) {
                            // Tomar el promedio simple de notas finales por materia si hubiera varias
                            $finales = [];
                            if (isset($m['ofertas'])) {
                                foreach ($m['ofertas'] as $of) {
                                    if (isset($of['notas'])) {
                                        foreach ($of['notas'] as $n) {
                                            if (isset($n['valor_final']) && $n['valor_final'] !== null) $finales[] = (float)$n['valor_final'];
                                        }
                                    }
                                }
                            }
                            $promMat = null;
                            if (!empty($finales)) {
                                $promMat = round(array_sum($finales)/count($finales), 2);
                            }
                            $semOut['materias'][] = [
                                'sigla' => $m['sigla'] ?? '',
                                'codigo' => $m['codigo'] ?? '',
                                'promedio_materia' => $promMat
                            ];
                        }
                    }
                    $resumen['semestres'][] = $semOut;
                }
            }
            $ctxNotas = $resumen;
            $messages[] = [
                'role' => 'system',
                'content' => "Datos verificables del sistema para responder sobre notas del alumno con nro_registro=$nroRegistro: " . json_encode($resumen, JSON_UNESCAPED_UNICODE)
            ];
        }
    }
}

// Ofertas de materias disponibles para el estudiante
if ($intencion === 'ofertas' && $nroRegistro !== '') {
    $url = 'https://im-ventas-de-computadoras.com/Sistema_Academico/oferta_estudiante.php?nro_registro=' . urlencode($nroRegistro);
    $ch2 = curl_init($url);
    curl_setopt($ch2, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch2, CURLOPT_TIMEOUT, 15);
    $resp2 = curl_exec($ch2);
    $st2 = curl_getinfo($ch2, CURLINFO_HTTP_CODE);
    curl_close($ch2);
    if ($resp2 !== false && $st2 >= 200 && $st2 < 300) {
        $json = json_decode($resp2, true);
        if (is_array($json) && isset($json['ok']) && $json['ok'] === true && isset($json['items'])) {
            $ofertas = [];
            foreach ($json['items'] as $o) {
                // Estructura: ver oferta_estudiante.php
                $sigla   = isset($o['materia']['sigla']) ? $o['materia']['sigla'] : '';
                $grupo   = $o['grupo'] ?? null;
                $cupos   = $o['cupos'] ?? null;
                $docente = '';
                if (isset($o['docente'])) {
                    $nom = $o['docente']['nombre'] ?? '';
                    $ape = $o['docente']['apellido'] ?? '';
                    $docente = trim($nom . ' ' . $ape);
                }
                $hora = '';
                if (isset($o['horario'])) {
                    $hi = $o['horario']['hora_inicio'] ?? '';
                    $hf = $o['horario']['hora_fin'] ?? '';
                    if ($hi || $hf) $hora = trim($hi . ' - ' . $hf);
                }
                $aula = '';
                if (isset($o['aula'])) {
                    $aula = $o['aula']['codigo'] ?? '';
                }
                $ofertas[] = [
                    'sigla'   => $sigla,
                    'grupo'   => $grupo,
                    'cupos'   => $cupos,
                    'docente' => $docente,
                    'horario' => $hora,
                    'aula'    => $aula,
                ];
                if (count($ofertas) >= 10) break; // limitar
            }
            $ctxOfertas = $ofertas;
            $messages[] = [
                'role' => 'system',
                'content' => 'Datos verificables del sistema sobre ofertas disponibles para el alumno con nro_registro=' . $nroRegistro . ': ' . json_encode($ofertas, JSON_UNESCAPED_UNICODE)
            ];
        }
    }
}

// Pensum del estudiante (malla + estado de materias)
if ($intencion === 'pensum' && $nroRegistro !== '') {
    $url = 'https://im-ventas-de-computadoras.com/Sistema_Academico/pensum_estudiante.php?nro_registro=' . urlencode($nroRegistro);
    $ch3 = curl_init($url);
    curl_setopt($ch3, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch3, CURLOPT_TIMEOUT, 15);
    $resp3 = curl_exec($ch3);
    $st3 = curl_getinfo($ch3, CURLINFO_HTTP_CODE);
    curl_close($ch3);
    if ($resp3 !== false && $st3 >= 200 && $st3 < 300) {
        $json = json_decode($resp3, true);
        if (is_array($json) && isset($json['ok']) && $json['ok'] === true && isset($json['pensum']) && is_array($json['pensum'])) {
            // Agrupar materias por semestre_pensum
            $bySem = [];
            foreach ($json['pensum'] as $it) {
                $sem = isset($it['semestre_pensum']) ? (int)$it['semestre_pensum'] : 0;
                if (!isset($bySem[$sem])) $bySem[$sem] = [];
                $bySem[$sem][] = [
                    'sigla'  => $it['sigla'] ?? ($it['materia_sigla'] ?? ''),
                    'codigo' => $it['codigo'] ?? ($it['materia_codigo'] ?? ''),
                ];
            }
            ksort($bySem, SORT_NUMERIC);
            $res = [ 'semestres' => [] ];
            foreach ($bySem as $sem => $mats) {
                $res['semestres'][] = [
                    'semestre' => ($sem === 0 ? null : $sem),
                    'materias' => array_slice($mats, 0, 8),
                ];
                if (count($res['semestres']) >= 6) break; // limitar
            }
            $ctxPensum = $res;
            $messages[] = [
                'role' => 'system',
                'content' => 'Datos verificables del sistema sobre el pensum del alumno con nro_registro=' . $nroRegistro . ': ' . json_encode($res, JSON_UNESCAPED_UNICODE)
            ];
        }
    }
}

if (!empty($historyInput)) {
    foreach ($historyInput as $m) {
        if (!is_array($m)) continue;
        $role = isset($m['role']) ? (string)$m['role'] : '';
        $content = isset($m['content']) ? (string)$m['content'] : '';
        if ($role !== 'user' && $role !== 'assistant' && $role !== 'system') continue;
        if ($content === '') continue;
        // Evitar que el cliente inyecte system messages adicionales
        if ($role === 'system') continue;
        $messages[] = [ 'role' => $role, 'content' => $content ];
    }
}

// Agregar el mensaje actual del usuario
$messages[] = [ 'role' => 'user', 'content' => $userMessage ];

// Limitar longitud del contexto (mantener los últimos N mensajes relevantes)
// Conservamos el primer system y hasta 12 interacciones previas
$maxPairs = 12; // 12 mensajes previos como máximo
$filtered = [ $messages[0] ];
$tail = array_slice($messages, -($maxPairs + 1)); // +1 por el user actual
foreach ($tail as $idx => $m) {
    if ($idx === 0) continue; // ya agregamos el system
    $filtered[] = $m;
}
$messages = $filtered;

// Preparar payload para Chat Completions
$payload = [
    'model' => 'gpt-4o-mini',
    'messages' => $messages,
    'temperature' => 0.2,
];

$ch = curl_init('https://api.openai.com/v1/chat/completions');
curl_setopt($ch, CURLOPT_HTTPHEADER, [
    'Content-Type: application/json',
    'Authorization: Bearer ' . $apiKey,
]);
curl_setopt($ch, CURLOPT_POST, true);
curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_TIMEOUT, 30);

$resp = curl_exec($ch);
if ($resp === false) {
    $err = curl_error($ch);
    curl_close($ch);
    // Fallback si contamos con contexto útil
    $fallback = null;
    if ($intencion === 'notas' && $ctxNotas) {
        $fallback = generar_fallback_notas($ctxNotas);
    } elseif ($intencion === 'ofertas' && $ctxOfertas) {
        $fallback = generar_fallback_ofertas($ctxOfertas);
    } elseif ($intencion === 'pensum' && $ctxPensum) {
        $fallback = generar_fallback_pensum($ctxPensum);
    }
    if ($fallback) {
        echo json_encode(['reply' => $fallback, 'via' => 'fallback']);
        exit;
    }
    http_response_code(502);
    echo json_encode(['error' => 'Error al contactar OpenAI', 'detail' => $err]);
    exit;
}

$status = curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

if ($status < 200 || $status >= 300) {
    // Fallback si contamos con contexto útil
    $fallback = null;
    if ($intencion === 'notas' && $ctxNotas) {
        $fallback = generar_fallback_notas($ctxNotas);
    } elseif ($intencion === 'ofertas' && $ctxOfertas) {
        $fallback = generar_fallback_ofertas($ctxOfertas);
    } elseif ($intencion === 'pensum' && $ctxPensum) {
        $fallback = generar_fallback_pensum($ctxPensum);
    }
    if ($fallback) {
        echo json_encode(['reply' => $fallback, 'via' => 'fallback']);
        exit;
    }
    http_response_code(502);
    echo json_encode(['error' => 'Respuesta no válida de OpenAI', 'status' => $status, 'raw' => $resp]);
    exit;
}

$decoded = json_decode($resp, true);
$reply = '';
if (isset($decoded['choices'][0]['message']['content'])) {
    $reply = (string)$decoded['choices'][0]['message']['content'];
}

echo json_encode([
    'reply' => $reply,
]);
// EOF

// ---- Fallback render helpers ----
function generar_fallback_notas($ctx) {
    $lineas = [];
    $prom = isset($ctx['promedio_final']) && $ctx['promedio_final'] !== null ? $ctx['promedio_final'] : null;
    if (!is_null($prom)) $lineas[] = "Promedio final: $prom";
    if (!empty($ctx['semestres'])) {
        foreach ($ctx['semestres'] as $s) {
            $sm = $s['semestre_pensum'] ?? 's/d';
            $lineas[] = "Semestre $sm:";
            if (!empty($s['materias'])) {
                $i = 0;
                foreach ($s['materias'] as $m) {
                    $sigla = $m['sigla'] ?? '';
                    $pm = isset($m['promedio_materia']) && $m['promedio_materia'] !== null ? $m['promedio_materia'] : 's/d';
                    $lineas[] = "- $sigla: promedio $pm";
                    if (++$i >= 8) break;
                }
            }
        }
    }
    if (empty($lineas)) return null;
    return "Resumen de tus notas (vista rápida):\n" . implode("\n", $lineas) . "\n\nPara más detalle, revisa la sección Notas del portal.";
}

function generar_fallback_ofertas($items) {
    if (empty($items)) return null;
    $out = ["Ofertas disponibles (máx 10):"];
    $i=0;
    foreach ($items as $o) {
        $sigla = $o['sigla'] ?? '';
        $mat   = $o['materia'] ?? '';
        $grp   = $o['grupo'] ?? '';
        $doc   = $o['docente'] ?? '';
        $cup   = $o['cupos'] ?? '';
        $out[] = "- $sigla $mat (Grupo $grp) Doc.: $doc Cupos: $cup";
        if (++$i >= 10) break;
    }
    return implode("\n", $out);
}

function generar_fallback_pensum($ctx) {
    if (empty($ctx['semestres'])) return null;
    $out = ["Pensum (resumen):"];
    $c=0;
    foreach ($ctx['semestres'] as $s) {
        $sem = $s['semestre'] ?? 's/d';
        $out[] = "Semestre $sem:";
        $i=0;
        foreach ($s['materias'] as $m) {
            $out[] = "- " . ($m['sigla'] ?? '') . " " . ($m['materia'] ?? '');
            if (++$i >= 8) break;
        }
        if (++$c >= 6) break;
    }
    return implode("\n", $out);
}