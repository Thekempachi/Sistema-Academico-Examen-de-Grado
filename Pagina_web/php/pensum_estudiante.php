<?php
// pensum_estudiante.php

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
        echo json_encode(['ok'=>false, 'error'=>'FALTAN_PARAMETROS', 'msg'=>'Envía nro_registro o id_estudiante']); exit;
    }

    // --- Resolver id_estudiante si llegó nro_registro ---
    if ($nro_registro !== '') {
        $sql = "SELECT id_Estudiante FROM estudiante WHERE nro_registro = ? LIMIT 1";
        $st  = $cn->prepare($sql);
        $st->bind_param('s', $nro_registro);
        $st->execute();
        $rs = $st->get_result();
        if ($rs->num_rows === 0) {
            echo json_encode([
                'ok'=>true,
                'estudiante'=>['nro_registro'=>$nro_registro, 'id_estudiante'=>null],
                'carrera'=>null,
                'plan_estudio'=>null,
                'pensum'=>[]
            ]); exit;
        }
        $row = $rs->fetch_assoc();
        $id_estudiante = (int)$row['id_Estudiante'];
        $st->close();
    } else {
        if (!ctype_digit($id_estudiante)) {
            http_response_code(400);
            echo json_encode(['ok'=>false, 'error'=>'ID_INVALIDO']); exit;
        }
        $id_estudiante = (int)$id_estudiante;
    }

    // --- Consulta principal ---
    // Trae: plan ACTIVO del estudiante + carrera + materias del pensum ACTIVO (con semestre_pensum)
    $sql = "
    SELECT
        pe.id_Plan_Estudio,
        pe.nro_Plan,
        pe.descripcion,
        pe.estado        AS plan_estado,
        pe.fecha_creacion,
        c.id_Carrera,
        c.codigo         AS carrera_codigo,
        c.nombre         AS carrera_nombre,

        pen.id_Materia,
        pen.estado_pensum,
        pen.semestre_pensum,             -- << requiere que la columna exista

        m.codigo         AS materia_codigo,
        m.sigla          AS materia_sigla

    FROM plan_estudio pe
    JOIN carrera c      ON c.id_Carrera = pe.id_Carrera
    LEFT JOIN pensum pen ON pen.id_Plan_Estudio = pe.id_Plan_Estudio
    LEFT JOIN materia m  ON m.id_Materia = pen.id_Materia

    WHERE pe.id_Estudiante = ?
      AND UPPER(pe.estado) = 'ACTIVO'
      AND (pen.id_Materia IS NULL OR UPPER(pen.estado_pensum) = 'ACTIVO')

    ORDER BY pen.semestre_pensum ASC, m.sigla ASC, m.id_Materia ASC
    ";

    $st = $cn->prepare($sql);
    $st->bind_param('i', $id_estudiante);
    $st->execute();
    $rs = $st->get_result();

    $plan = null;
    $carrera = null;
    $pensum = [];

    while ($r = $rs->fetch_assoc()) {
        // Plan y carrera se repiten por fila: setearlos una sola vez
        if ($plan === null) {
            $plan = [
                'id_plan_estudio' => (int)$r['id_Plan_Estudio'],
                'nro_plan'        => $r['nro_Plan'],
                'descripcion'     => $r['descripcion'],
                'estado'          => $r['plan_estado'],
                'fecha_creacion'  => $r['fecha_creacion']
            ];
        }
        if ($carrera === null) {
            $carrera = [
                'id_carrera' => (int)$r['id_Carrera'],
                'codigo'     => $r['carrera_codigo'],
                'nombre'     => $r['carrera_nombre']
            ];
        }

        // Si no hay materia (plan sin detalles de pensum), saltar push
        if (!is_null($r['id_Materia'])) {
            $pensum[] = [
                'id_materia'      => (int)$r['id_Materia'],
                'codigo'          => $r['materia_codigo'],
                'sigla'           => $r['materia_sigla'],
                'semestre_pensum' => isset($r['semestre_pensum']) ? (int)$r['semestre_pensum'] : null,
                'estado_pensum'   => $r['estado_pensum']
            ];
        }
    }
    $st->close();
    $cn->close();

    echo json_encode([
        'ok' => true,
        'estudiante' => [
            'nro_registro'  => ($nro_registro !== '' ? $nro_registro : null),
            'id_estudiante' => $id_estudiante
        ],
        'carrera'      => $carrera,
        'plan_estudio' => $plan,
        'pensum'       => $pensum
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false, 'error'=>'SERVER_ERROR', 'msg'=>$e->getMessage()]);
}
