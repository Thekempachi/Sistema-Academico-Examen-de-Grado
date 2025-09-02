<?php
// Pagina_web/php/asignar_asistencia.php

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');
require_once 'conexion.php';
// session_start();

// Recibe: id_Estudiante, id_Oferta_Materia, fecha, observacion

$data = json_decode(file_get_contents('php://input'), true);
if (!isset($data['id_Estudiante'], $data['id_Oferta_Materia'], $data['fecha'])) {
    echo json_encode(['ok'=>false, 'error'=>'FALTAN_DATOS']);
    exit;
}
$id_est = $data['id_Estudiante'];
$id_oferta = $data['id_Oferta_Materia'];
$fecha = $data['fecha'];
$obs = isset($data['observacion']) ? $data['observacion'] : null;


// Usar el procedimiento almacenado Asistencia_Registrar_SinObservacion
$sql_est = "SELECT nro_registro FROM estudiante WHERE id_Estudiante = ? LIMIT 1";
$stmt_est = $conn->prepare($sql_est);
$stmt_est->bind_param('i', $id_est);
$stmt_est->execute();
$res_est = $stmt_est->get_result();
$row_est = $res_est->fetch_assoc();
if (!$row_est) {
    echo json_encode(['ok'=>false, 'error'=>'ESTUDIANTE_NOT_FOUND']);
    exit;
}
$nro_registro = $row_est['nro_registro'];
$stmt_est->close();

$p_status = null;
$stmt = $conn->prepare("CALL Asistencia_Registrar_SinObservacion(?, ?, ?, @p_status)");
$stmt->bind_param('sis', $nro_registro, $id_oferta, $fecha);
if (!$stmt->execute()) {
    echo json_encode(['ok'=>false, 'error'=>'PROC_ASISTENCIA: '.$conn->error]);
    exit;
}
$stmt->close();
$res = $conn->query("SELECT @p_status AS status");
$row = $res->fetch_assoc();
if ($row['status'] !== 'ok') {
    echo json_encode(['ok'=>false, 'error'=>'PROC_ASISTENCIA: '.$row['status']]);
    exit;
}
echo json_encode(['ok'=>true, 'msg'=>'Asistencia registrada.']);
