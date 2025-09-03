<?php
// materias_estudiante.php

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
    $nro_registro   = isset($_POST['nro_registro']) ? trim($_POST['nro_registro']) : (isset($_GET['nro_registro']) ? trim($_GET['nro_registro']) : '');
    $id_estudiante  = isset($_POST['id_estudiante']) ? trim($_POST['id_estudiante']) : (isset($_GET['id_estudiante']) ? trim($_GET['id_estudiante']) : '');

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
            echo json_encode(['ok'=>true, 'estudiante'=>['nro_registro'=>$nro_registro, 'id_estudiante'=>null], 'items'=>[]]); exit;
        }
        $row = $rs->fetch_assoc();
        $id_estudiante = $row['id_Estudiante'];
        $st->close();
    } else {
        // normalizar a entero
        if (!ctype_digit($id_estudiante)) {
            http_response_code(400);
            echo json_encode(['ok'=>false, 'error'=>'ID_INVALIDO']); exit;
        }
        $id_estudiante = (int)$id_estudiante;
    }

    // --- Query principal: materias/ofertas del estudiante ---
    $sql = "
    SELECT
        rm.id_Registro_Materia                          AS id_registro_materia,
        rm.estado                                       AS estado_registro,

        om.id_Oferta_Materia                            AS id_oferta_materia,
        om.estado                                       AS estado_oferta,
        COALESCE(om.cupos, om.cupo_max)                 AS cupos,           -- maneja ambos nombres
        om.fecha_creacion                               AS fecha_creacion,
        om.grupo                                        AS grupo,
        om.id_Usuario                                   AS id_usuario_oferta,
        om.id_Docente                                   AS id_docente,
        om.id_Aula                                      AS id_aula,
        om.id_Horario                                   AS id_horario,

        pdoc.nombre                                     AS docente_nombre,
        pdoc.apellido                                   AS docente_apellido,

        a.codigo                                        AS aula_codigo,

        h.hora_inicio                                   AS hora_inicio,
        h.hora_fin                                      AS hora_fin
    FROM registro_materia rm
    JOIN oferta_materia  om  ON om.id_Oferta_Materia = rm.id_Oferta_Materia
    LEFT JOIN docente    d   ON d.id_Docente = om.id_Docente
    LEFT JOIN usuario    udoc ON udoc.id_Usuario = d.id_Docente
    LEFT JOIN persona    pdoc ON pdoc.id_Persona = udoc.id_Usuario
    LEFT JOIN aula       a    ON a.id_Aula = om.id_Aula
    LEFT JOIN horario    h    ON h.id_Horario = om.id_Horario
    WHERE rm.id_Estudiante = ?
    ORDER BY om.grupo, om.id_Oferta_Materia
    ";

    $st  = $cn->prepare($sql);
    $st->bind_param('i', $id_estudiante);
    $st->execute();
    $rs  = $st->get_result();

    $items = [];
    while ($r = $rs->fetch_assoc()) {
        $items[] = [
            'id_registro_materia' => (int)$r['id_registro_materia'],
            'estado_registro'     => $r['estado_registro'],

            'oferta' => [
                'id_oferta_materia'  => (int)$r['id_oferta_materia'],
                'estado'             => $r['estado_oferta'],
                'cupos'              => is_null($r['cupos']) ? null : (int)$r['cupos'],
                'fecha_creacion'     => $r['fecha_creacion'],
                'grupo'              => $r['grupo'],
                'id_usuario_oferta'  => is_null($r['id_usuario_oferta']) ? null : (int)$r['id_usuario_oferta'],
                'id_docente'         => is_null($r['id_docente']) ? null : (int)$r['id_docente'],
                'id_aula'            => is_null($r['id_aula']) ? null : (int)$r['id_aula'],
                'id_horario'         => is_null($r['id_horario']) ? null : (int)$r['id_horario'],
            ],

            'docente' => [
                'nombre'   => $r['docente_nombre'],
                'apellido' => $r['docente_apellido'],
            ],

            'aula' => [
                'codigo' => $r['aula_codigo'],
            ],

            'horario' => [
                'hora_inicio' => $r['hora_inicio'],
                'hora_fin'    => $r['hora_fin'],
            ],
        ];
    }
    $st->close();
    $cn->close();

    echo json_encode([
        'ok' => true,
        'estudiante' => [
            'nro_registro'  => $nro_registro !== '' ? $nro_registro : null,
            'id_estudiante' => (int)$id_estudiante
        ],
        'items' => $items
    ]);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false, 'error'=>'SERVER_ERROR', 'msg'=>$e->getMessage()]);
}