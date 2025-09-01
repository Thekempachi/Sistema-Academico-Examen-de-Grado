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

// Insertar o actualizar asistencia
$sql = "INSERT INTO asistencia (id_Estudiante, id_Oferta_Materia, fecha, observacion)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE observacion=VALUES(observacion), fecha=VALUES(fecha)";
$stmt = $conn->prepare($sql);
$stmt->bind_param('iiss', $id_est, $id_oferta, $fecha, $obs);
if ($stmt->execute()) {
    echo json_encode(['ok'=>true]);
} else {
    echo json_encode(['ok'=>false, 'error'=>$conn->error]);
}
