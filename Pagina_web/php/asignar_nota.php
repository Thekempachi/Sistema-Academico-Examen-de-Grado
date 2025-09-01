<?php
// Pagina_web/php/asignar_nota.php

header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json');
require_once 'conexion.php';
// session_start();

// Recibe: id_Estudiante, id_Oferta_Materia, id_Docente, tipo, valor, fecha, observacion
$data = json_decode(file_get_contents('php://input'), true);
if (!isset($data['id_Estudiante'], $data['id_Oferta_Materia'], $data['id_Docente'], $data['tipo'], $data['valor'], $data['fecha'])) {
    echo json_encode(['ok'=>false, 'error'=>'FALTAN_DATOS']);
    exit;
}
$id_est = $data['id_Estudiante'];
$id_oferta = $data['id_Oferta_Materia'];
$id_doc = $data['id_Docente'];
$tipo = $data['tipo'];
$valor = $data['valor'];
$fecha = $data['fecha'];
$obs = isset($data['observacion']) ? $data['observacion'] : null;

// Insertar nota (puedes mejorar para actualizar si ya existe)
$sql = "INSERT INTO nota_parcial (tipo, valor, fecha, observacion, id_Docente, id_Estudiante, id_Oferta_Materia)
        VALUES (?, ?, ?, ?, ?, ?, ?)";
$stmt = $conn->prepare($sql);
$stmt->bind_param('sdssiis', $tipo, $valor, $fecha, $obs, $id_doc, $id_est, $id_oferta);
if ($stmt->execute()) {
    echo json_encode(['ok'=>true]);
} else {
    echo json_encode(['ok'=>false, 'error'=>$conn->error]);
}
