<?php
// ofertas_estudiante.php

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
    $nro_registro  = isset($_POST['nro_registro']) ? trim($_POST['nro_registro']) : (isset($_GET['nro_registro']) ? trim($_GET['nro_registro']) : '');
    $id_estudiante = isset($_POST['id_estudiante']) ? trim($_POST['id_estudiante']) : (isset($_GET['id_estudiante']) ? trim($_GET['id_estudiante']) : '');

    if ($nro_registro === '' && $id_estudiante === '') {
        http_response_code(400);
        echo json_encode(['ok'=>false, 'error'=>'FALTAN_PARAMETROS', 'msg'=>'Envía nro_registro o id_estudiante']); exit;
    }

    // Resolver id_estudiante si llega nro_registro
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
                'items'=>[]
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

    // Consulta principal: Ofertas del periodo ACTIVO y ABIERTAS, no registradas ni cursadas por el estudiante
    $sql = "
    SELECT
      om.id_Oferta_Materia,
      om.grupo,
      om.cupos,
      om.fecha_creacion,

      m.id_Materia,
      m.sigla,

      a.codigo       AS aula_codigo,
      a.bloque       AS aula_bloque,

      h.hora_inicio,
      h.hora_fin,

      pdoc.nombre    AS docente_nombre,
      pdoc.apellido  AS docente_apellido
    FROM oferta_materia om
    JOIN periodo_academico pa ON pa.id_Periodo_Academico = om.id_Periodo_Academico
    JOIN materia        m  ON m.id_Materia  = om.id_Materia
    LEFT JOIN aula      a  ON a.id_Aula     = om.id_Aula
    LEFT JOIN horario   h  ON h.id_Horario  = om.id_Horario
    LEFT JOIN docente   d  ON d.id_Docente  = om.id_Docente
    LEFT JOIN usuario   u  ON u.id_Usuario  = d.id_Docente
    LEFT JOIN persona   pdoc ON pdoc.id_Persona = u.id_Usuario
    WHERE UPPER(pa.estado) = 'ACTIVO'
      AND UPPER(om.estado) = 'ABIERTA'

      -- No está registrada en esta oferta
      AND NOT EXISTS (
        SELECT 1
        FROM registro_materia rm
        WHERE rm.id_Oferta_Materia = om.id_Oferta_Materia
          AND rm.id_Estudiante     = ?
          AND UPPER(rm.estado) = 'REGISTRADO'
      )

      -- No ha cursado esta materia en ninguna oferta previa (registrado/aprobado/reprobado/retirado)
      AND NOT EXISTS (
        SELECT 1
        FROM registro_materia rm2
        JOIN oferta_materia  om2 ON om2.id_Oferta_Materia = rm2.id_Oferta_Materia
        WHERE rm2.id_Estudiante = ?
          AND om2.id_Materia    = om.id_Materia
          AND UPPER(rm2.estado) IN ('APROBADO','REPROBADO','RETIRADO','REGISTRADO')
      )
    ORDER BY m.sigla, om.grupo, om.id_Oferta_Materia
    ";

    $st = $cn->prepare($sql);
    $st->bind_param('ii', $id_estudiante, $id_estudiante);
    $st->execute();
    $rs = $st->get_result();

    $items = [];
    while ($r = $rs->fetch_assoc()) {
        $items[] = [
            'id_oferta_materia' => (int)$r['id_Oferta_Materia'],
            'grupo'             => $r['grupo'],
            'cupos'             => is_null($r['cupos']) ? null : (int)$r['cupos'],
            'fecha_creacion'    => $r['fecha_creacion'],

            'materia' => [
                'id_materia' => (int)$r['id_Materia'],
                'sigla'      => $r['sigla'],
            ],

            'aula' => [
                'codigo' => $r['aula_codigo'],
                'bloque' => $r['aula_bloque'],
            ],

            'horario' => [
                'hora_inicio' => $r['hora_inicio'],
                'hora_fin'    => $r['hora_fin'],
            ],

            'docente' => [
                'nombre'   => $r['docente_nombre'],
                'apellido' => $r['docente_apellido'],
            ],
        ];
    }
    $st->close();
    $cn->close();

    echo json_encode([
        'ok' => true,
        'estudiante' => [
            'nro_registro'  => ($nro_registro !== '' ? $nro_registro : null),
            'id_estudiante' => $id_estudiante
        ],
        'items' => $items
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false, 'error'=>'SERVER_ERROR', 'msg'=>$e->getMessage()]);
}
