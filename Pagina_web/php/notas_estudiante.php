<?php
// notas_estudiante.php

// Debug (desactiva en producción)
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
ini_set('display_errors', 1);
error_reporting(E_ALL);

// CORS/JSON
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// --- Conexión BD ---
$servername = "localhost";
$username   = "u605613151_admin";
$password   = "C0ntrasenPassword@";
$dbname     = "u605613151_sistema_academ";

try {
  $cn = new mysqli($servername, $username, $password, $dbname);
  $cn->set_charset("utf8mb4");

  // --- Inputs ---
  $nro_registro  = isset($_POST['nro_registro']) ? trim($_POST['nro_registro']) :
                   (isset($_GET['nro_registro']) ? trim($_GET['nro_registro']) : '');
  $id_estudiante = isset($_POST['id_estudiante']) ? trim($_POST['id_estudiante']) :
                   (isset($_GET['id_estudiante']) ? trim($_GET['id_estudiante']) : '');

  if ($nro_registro === '' && $id_estudiante === '') {
    http_response_code(400);
    echo json_encode(['ok'=>false, 'error'=>'FALTAN_PARAMETROS', 'msg'=>'Envía nro_registro o id_estudiante']);
    exit;
  }

  // --- Resolver id_estudiante si llegó nro_registro ---
  if ($nro_registro !== '') {
    $st = $cn->prepare("SELECT id_Estudiante, id_Carrera FROM estudiante WHERE nro_registro = ? LIMIT 1");
    $st->bind_param('s', $nro_registro);
    $st->execute();
    $rs = $st->get_result();
    if ($rs->num_rows === 0) {
      echo json_encode([
        'ok'=>true,
        'estudiante'=>['nro_registro'=>$nro_registro, 'id_estudiante'=>null],
        'promedio_final'=>null,
        'semestres'=>[]
      ]);
      exit;
    }
    $row = $rs->fetch_assoc();
    $id_estudiante = (int)$row['id_Estudiante'];
    $id_carrera    = isset($row['id_Carrera']) ? (int)$row['id_Carrera'] : null;
    $st->close();
  } else {
    if (!ctype_digit($id_estudiante)) {
      http_response_code(400);
      echo json_encode(['ok'=>false, 'error'=>'ID_INVALIDO']);
      exit;
    }
    $id_estudiante = (int)$id_estudiante;

    // Obtener id_carrera a partir del estudiante
    $st = $cn->prepare("SELECT id_Carrera FROM estudiante WHERE id_Estudiante = ? LIMIT 1");
    $st->bind_param('i', $id_estudiante);
    $st->execute();
    $rs = $st->get_result();
    $row = $rs->fetch_assoc();
    $id_carrera = $row ? (int)$row['id_Carrera'] : null;
    $st->close();
  }

  // --- Obtener plan de estudio ACTIVO de la carrera del estudiante (si existe) ---
  // Toma el más reciente si hubiera más de uno activo
  $id_plan_estudio = null;
  if (!is_null($id_carrera)) {
    $sqlPlan = "
      SELECT pe.id_Plan_Estudio
      FROM plan_estudio pe
      WHERE pe.id_Carrera = ?
        AND UPPER(pe.estado) = 'ACTIVO'
      ORDER BY pe.fecha_creacion DESC, pe.id_Plan_Estudio DESC
      LIMIT 1
    ";
    $st = $cn->prepare($sqlPlan);
    $st->bind_param('i', $id_carrera);
    $st->execute();
    $rs = $st->get_result();
    if ($rs && $rs->num_rows > 0) {
      $id_plan_estudio = (int)$rs->fetch_assoc()['id_Plan_Estudio'];
    }
    $st->close();
  }

  // --- Calcular promedio final usando la función almacenada ---
  // SELECT fn_promedio_final_estudiante(?) AS promedio;
  $promedio_final = null;
  if ($nro_registro !== '') {
    $st = $cn->prepare("SELECT fn_promedio_final_estudiante(?) AS promedio");
    $st->bind_param('s', $nro_registro);
    $st->execute();
    $rs = $st->get_result();
    if ($rs && $rs->num_rows > 0) {
      $rfun = $rs->fetch_assoc();
      // La función redondea .5 hacia arriba y devuelve entero (o NULL si no hay notas)
      $promedio_final = isset($rfun['promedio']) ? (is_null($rfun['promedio']) ? null : (int)$rfun['promedio']) : null;
    }
    $st->close();
  }

  // --- Notas parciales de todas las ofertas del estudiante,
  //     aplicando la última corrección si existe (valor_final) ---
  //     y mapeando el semestre a través del pensum del plan ACTIVO (si lo hay)
  $items = [];

  if ($id_plan_estudio) {
    // Con plan activo: podemos obtener semestre_pensum real
    $sql = "
      SELECT
        pen.semestre_pensum                                    AS semestre_pensum,
        m.id_Materia                                           AS id_materia,
        m.sigla                                                AS sigla,
        m.codigo                                               AS codigo_materia,

        om.id_Oferta_Materia                                   AS id_oferta_materia,

        np.id_Nota_Parcial                                     AS id_nota_parcial,
        np.valor                                               AS valor_original,
        COALESCE(c.valor_nuevo, np.valor)                      AS valor_final,
        np.descripcion                                          AS descripcion,
        np.fecha_registro                                      AS fecha_registro

      FROM nota_parcial np
      JOIN oferta_materia om ON om.id_Oferta_Materia = np.id_Oferta_Materia
      JOIN materia m        ON m.id_Materia         = om.id_Materia

      LEFT JOIN (
        SELECT c1.id_Nota_Parcial, c1.valor_nuevo
        FROM correcion_nota c1
        JOIN (
          SELECT id_Nota_Parcial, MAX(fecha_correcion) AS max_fecha
          FROM correcion_nota
          GROUP BY id_Nota_Parcial
        ) ult ON ult.id_Nota_Parcial = c1.id_Nota_Parcial
             AND ult.max_fecha       = c1.fecha_correcion
      ) c ON c.id_Nota_Parcial = np.id_Nota_Parcial

      LEFT JOIN pensum pen
        ON pen.id_Materia = m.id_Materia
       AND pen.id_Plan_Estudio = ?

      WHERE np.id_Estudiante = ?
      ORDER BY
        (pen.semestre_pensum IS NULL), pen.semestre_pensum,
        m.sigla, om.id_Oferta_Materia, np.id_Nota_Parcial
    ";
    $st = $cn->prepare($sql);
    $st->bind_param('ii', $id_plan_estudio, $id_estudiante);
  } else {
    // Sin plan activo: devolvemos semestre_pensum null
    $sql = "
      SELECT
        NULL                                                  AS semestre_pensum,
        m.id_Materia                                          AS id_materia,
        m.sigla                                               AS sigla,
        m.codigo                                              AS codigo_materia,

        om.id_Oferta_Materia                                  AS id_oferta_materia,

        np.id_Nota_Parcial                                    AS id_nota_parcial,
        np.valor                                              AS valor_original,
        COALESCE(c.valor_nuevo, np.valor)                     AS valor_final,
        np.descripcion                                         AS descripcion,
        np.fecha_registro                                     AS fecha_registro

      FROM nota_parcial np
      JOIN oferta_materia om ON om.id_Oferta_Materia = np.id_Oferta_Materia
      JOIN materia m        ON m.id_Materia         = om.id_Materia

      LEFT JOIN (
        SELECT c1.id_Nota_Parcial, c1.valor_nuevo
        FROM correcion_nota c1
        JOIN (
          SELECT id_Nota_Parcial, MAX(fecha_correcion) AS max_fecha
          FROM correcion_nota
          GROUP BY id_Nota_Parcial
        ) ult ON ult.id_Nota_Parcial = c1.id_Nota_Parcial
             AND ult.max_fecha       = c1.fecha_correcion
      ) c ON c.id_Nota_Parcial = np.id_Nota_Parcial

      WHERE np.id_Estudiante = ?
      ORDER BY m.sigla, om.id_Oferta_Materia, np.id_Nota_Parcial
    ";
    $st = $cn->prepare($sql);
    $st->bind_param('i', $id_estudiante);
  }

  $st->execute();
  $rs = $st->get_result();

  // --- Agrupar en PHP por semestre -> materia -> oferta -> notas ---
  $by_semestre = []; // [semestre] => [ materias => [ id_materia => [...]]]

  while ($r = $rs->fetch_assoc()) {
    $sem = isset($r['semestre_pensum']) ? $r['semestre_pensum'] : null;
    // Usamos 0 para "Sin mapeo" y así mantener la estructura consistente
    $sem_key = is_null($sem) ? 0 : (int)$sem;

    if (!isset($by_semestre[$sem_key])) {
      $by_semestre[$sem_key] = [
        'semestre' => is_null($sem) ? null : (int)$sem,
        'materias' => []
      ];
    }

    $id_materia = (int)$r['id_materia'];
    if (!isset($by_semestre[$sem_key]['materias'][$id_materia])) {
      $by_semestre[$sem_key]['materias'][$id_materia] = [
        'id_materia' => $id_materia,
        'sigla'      => $r['sigla'],
        'codigo'     => $r['codigo_materia'],
        'ofertas'    => []
      ];
    }

    $id_oferta = (int)$r['id_oferta_materia'];
    if (!isset($by_semestre[$sem_key]['materias'][$id_materia]['ofertas'][$id_oferta])) {
      $by_semestre[$sem_key]['materias'][$id_materia]['ofertas'][$id_oferta] = [
        'id_oferta_materia' => $id_oferta,
        'notas' => []
      ];
    }

    $nota = [
      'id_nota_parcial' => (int)$r['id_nota_parcial'],
      'valor_original'  => is_null($r['valor_original']) ? null : (float)$r['valor_original'],
      'valor_final'     => is_null($r['valor_final'])    ? null : (float)$r['valor_final'],
      'descripcion'     => $r['descripcion'],
      'fecha_registro'  => $r['fecha_registro'],
    ];

    $by_semestre[$sem_key]['materias'][$id_materia]['ofertas'][$id_oferta]['notas'][] = $nota;
  }

  $st->close();
  $cn->close();

  // Normalizar estructura para salida (arrays ordenados por semestre asc)
  ksort($by_semestre, SORT_NUMERIC);
  $semestres_out = [];
  foreach ($by_semestre as $sem_key => $payload) {
    // materias: transformar mapa -> array
    $materias_arr = array_values($payload['materias']);
    // ordenar por sigla
    usort($materias_arr, function($a, $b){
      return strcmp($a['sigla'] ?? '', $b['sigla'] ?? '');
    });

    // dentro de cada materia, ofertas como array
    foreach ($materias_arr as &$mat) {
      $mat['ofertas'] = array_values($mat['ofertas']);
      // ordenar por id_oferta_materia
      usort($mat['ofertas'], function($a, $b){
        return ($a['id_oferta_materia'] <=> $b['id_oferta_materia']);
      });
    }

    $semestres_out[] = [
      'semestre_pensum' => $payload['semestre'],
      'materias'        => $materias_arr
    ];
  }

  echo json_encode([
    'ok' => true,
    'estudiante' => [
      'nro_registro'  => $nro_registro !== '' ? $nro_registro : null,
      'id_estudiante' => (int)$id_estudiante
    ],
    'plan_estudio' => [
      'id_plan_estudio' => $id_plan_estudio
    ],
    'promedio_final' => $promedio_final, // entero o null
    'semestres' => $semestres_out
  ]);

} catch (Throwable $e) {
  http_response_code(500);
  echo json_encode(['ok'=>false, 'error'=>'SERVER_ERROR', 'msg'=>$e->getMessage()]);
}