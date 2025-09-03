<?php
// Pagina_web/php/asignar_asistencia.php


header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Content-Type: application/json');
// Responder preflight CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
// Conexión directa a la base de datos
$servername = "localhost";
$username   = "u605613151_admin";
$password   = "C0ntrasenPassword@";
$dbname     = "u605613151_sistema_academ";
// Forzar excepciones de mysqli para capturarlas y responder JSON
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);

try {
    $conn = new mysqli($servername, $username, $password, $dbname);
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false,'error'=>'DB_CONN_ERROR','msg'=>$e->getMessage()]);
    exit;
}
if ($conn->connect_error) {
    die(json_encode(['ok'=>false, 'error'=>'DB_CONN_ERROR', 'msg'=>$conn->connect_error]));
}
$conn->set_charset("utf8mb4");
// session_start();

// Recibe: id_Estudiante, id_Oferta_Materia, fecha, observacion


// Intentar JSON; si no, caer a formulario/urlencoded
$raw = file_get_contents('php://input');
$data = json_decode($raw, true);
if (!$data || !is_array($data)) {
    // fallback: leer POST normal
    $data = [
        'id_Estudiante'     => $_POST['id_Estudiante']     ?? null,
        'id_Oferta_Materia' => $_POST['id_Oferta_Materia'] ?? null,
        'fecha'             => $_POST['fecha']             ?? null,
        'observacion'       => $_POST['observacion']       ?? null,
    ];
}
if (!is_array($data) || !isset($data['id_Estudiante'], $data['id_Oferta_Materia'], $data['fecha'])) {
    http_response_code(400);
    echo json_encode([
        'ok'=>false,
        'error'=>'FALTAN_DATOS',
        'debug'=>[
            'has_raw'=> (bool)($raw),
            'content_type'=> $_SERVER['CONTENT_TYPE'] ?? null,
            'method'=> $_SERVER['REQUEST_METHOD'] ?? null,
            'post_keys'=> array_keys($_POST ?? []),
        ]
    ]);
    exit;
}
$id_est = $data['id_Estudiante'];
$id_oferta = $data['id_Oferta_Materia'];
$fecha = $data['fecha'];
$obs = isset($data['observacion']) ? $data['observacion'] : null;


// Usar el procedimiento almacenado Asistencia_Registrar_SinObservacion
$sql_est = "SELECT nro_registro FROM estudiante WHERE id_Estudiante = ? LIMIT 1";
try {
    $stmt_est = $conn->prepare($sql_est);
    $stmt_est->bind_param('i', $id_est);
    $stmt_est->execute();
    // bind_result/fetch para máxima compatibilidad
    $nro_registro = null;
    $stmt_est->bind_result($nro_registro);
    $fetched = $stmt_est->fetch();
    $stmt_est->close();
    if (!$fetched || !$nro_registro) {
        http_response_code(404);
        echo json_encode([
            'ok'=>false,
            'error'=>'ESTUDIANTE_NOT_FOUND',
            'debug'=>['id_Estudiante'=>$id_est]
        ]);
        exit;
    }
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false,'error'=>'ESTUDIANTE_LOOKUP_ERROR','msg'=>$e->getMessage()]);
    exit;
}

// Normalizar fecha si viene solo YYYY-MM-DD
if (preg_match('/^\d{4}-\d{2}-\d{2}$/', $fecha)) {
    $fecha = $fecha . ' 00:00:00';
}

try {
    $stmt = $conn->prepare("CALL Asistencia_Registrar_SinEstatus(?, ?, ?)");
    $stmt->bind_param('sis', $nro_registro, $id_oferta, $fecha);
    $stmt->execute();
    $stmt->close();
    // Consumir posibles resultsets residuales
    while ($conn->more_results()) { $conn->next_result(); }
} catch (mysqli_sql_exception $e) {
    http_response_code(500);
    // Si ya existe el registro (PK/UK duplicada), tratar como idempotente
    if ((int)$e->getCode() === 1062 || (strpos($e->getMessage(), 'Duplicate entry') !== false)) {
        echo json_encode([
            'ok'=>true,
            'msg'=>'Asistencia ya estaba registrada (idempotente).',
            'debug'=>[
                'nro_registro'=>$nro_registro,
                'id_oferta'=>$id_oferta,
                'fecha'=>$fecha,
                'duplicate'=>true
            ]
        ]);
        exit;
    }
    echo json_encode([
        'ok'=>false,
        'error'=>'PROC_ASISTENCIA',
        'msg'=>$e->getMessage(),
        'debug'=>[
            'nro_registro'=>$nro_registro,
            'id_oferta'=>$id_oferta,
            'fecha'=>$fecha
        ]
    ]);
    exit;
}
echo json_encode([
    'ok'=>true,
    'msg'=>'Asistencia registrada.',
    'debug'=>[
        'payload'=>$data,
        'nro_registro'=>$nro_registro,
        'id_oferta'=>$id_oferta,
        'fecha'=>$fecha
    ]
]);
