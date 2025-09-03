<?php
// Pagina_web/php/corregir_nota.php
// Corrige (modifica) una nota parcial existente usando el SP Correcion_Nota

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// Conexión BD (mismo esquema que otros endpoints)
$host     = "localhost";
$dbname   = "u605613151_sistema_academ";
$user     = "u605613151_admin";
$password = "C0ntrasenPassword@";

try {
    $cn = new mysqli($host, $user, $password, $dbname);
    $cn->set_charset('utf8mb4');

    // Entrada: JSON (POST) o querystring (GET)
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $data = json_decode(file_get_contents('php://input'), true);
        $id_nota_parcial = isset($data['id_Nota_Parcial']) ? (int)$data['id_Nota_Parcial'] : null;
        $valor_nuevo     = isset($data['valor_nuevo']) ? (float)$data['valor_nuevo'] : null;
        $motivo          = isset($data['motivo']) ? trim((string)$data['motivo']) : '';
    } else {
        $id_nota_parcial = isset($_GET['id_Nota_Parcial']) ? (int)$_GET['id_Nota_Parcial'] : null;
        $valor_nuevo     = isset($_GET['valor_nuevo']) ? (float)$_GET['valor_nuevo'] : null;
        $motivo          = isset($_GET['motivo']) ? trim((string)$_GET['motivo']) : '';
    }

    if (!$id_nota_parcial || $valor_nuevo === null) {
        http_response_code(400);
        echo json_encode(['ok'=>false, 'error'=>'FALTAN_DATOS']);
        exit;
    }

    // Llamar al SP Correcion_Nota
    $stmt = $cn->prepare("CALL Correcion_Nota(?, ?, ?, @p_id_correcion, @p_status)");
    $stmt->bind_param('ids', $id_nota_parcial, $valor_nuevo, $motivo);
    if (!$stmt->execute()) {
        echo json_encode(['ok'=>false, 'error'=>'PROC_CORRECCION_EXEC', 'msg'=>$cn->error]);
        exit;
    }
    $stmt->close();

    $res = $cn->query("SELECT @p_id_correcion AS id_correcion, @p_status AS status");
    $row = $res ? $res->fetch_assoc() : null;
    if (!$row) {
        echo json_encode(['ok'=>false, 'error'=>'PROC_CORRECCION_NULL']);
        exit;
    }

    if ($row['status'] !== 'OK') {
        echo json_encode(['ok'=>false, 'error'=>'PROC_CORRECCION_STATUS', 'status'=>$row['status']]);
        exit;
    }

    echo json_encode(['ok'=>true, 'id_correcion' => (int)$row['id_correcion'], 'status'=>'OK']);

} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok'=>false, 'error'=>'SERVER_ERROR', 'msg'=>$e->getMessage()]);
}

