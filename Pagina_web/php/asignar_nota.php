<?php
// Pagina_web/php/asignar_nota.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');

// Conexión manual
$host     = "localhost";
$dbname   = "u605613151_sistema_academ";
$user     = "u605613151_admin";
$password = "C0ntrasenPassword@";
$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");




// Permitir datos por POST (JSON) o GET (URL)
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $data = json_decode(file_get_contents('php://input'), true);
    $nro_registro = isset($data['nro_registro']) ? $data['nro_registro'] : null;
    $id_oferta = isset($data['id_Oferta_Materia']) ? $data['id_Oferta_Materia'] : null;
    $valor = isset($data['valor']) ? $data['valor'] : null;
    $id_docente = isset($data['id_Docente']) ? $data['id_Docente'] : null;
} else {
    $nro_registro = isset($_GET['nro_registro']) ? $_GET['nro_registro'] : null;
    $id_oferta = isset($_GET['id_Oferta_Materia']) ? $_GET['id_Oferta_Materia'] : null;
    $valor = isset($_GET['valor']) ? $_GET['valor'] : null;
    $id_docente = isset($_GET['id_Docente']) ? $_GET['id_Docente'] : null;
}
if (!$nro_registro || !$id_oferta || $valor === null || !$id_docente) {
    echo json_encode(['ok'=>false, 'error'=>'FALTAN_DATOS']);
    exit;
}

// Usar el nuevo procedimiento almacenado NotaParcial_Insertar_Simple (sin observacion ni tipo)
$p_id_nota = null;
$p_status = null;
$stmt = $conn->prepare("CALL NotaParcial_Insertar_Simple(?, ?, ?, ?, @p_id_nota, @p_status)");
$stmt->bind_param('sidi', $nro_registro, $id_docente, $id_oferta, $valor);
if (!$stmt->execute()) {
    echo json_encode(['ok'=>false, 'error'=>'PROC_NOTA: '.$conn->error]);
    exit;
}
$stmt->close();
$res = $conn->query("SELECT @p_id_nota AS id_nota, @p_status AS status");
$row = $res->fetch_assoc();
if ($row['status'] !== 'OK') {
    echo json_encode(['ok'=>false, 'error'=>'PROC_NOTA: '.$row['status']]);
    exit;
}
echo json_encode(['ok'=>true, 'msg'=>'Nota registrada.', 'id_nota'=>$row['id_nota']]);
