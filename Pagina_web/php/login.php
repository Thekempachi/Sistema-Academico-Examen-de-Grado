<?php
// Debug (desactiva en producción)
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
ini_set('display_errors', 1);
error_reporting(E_ALL);

// CORS/JSON
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// BD
$servername = "localhost";
$username   = "u605613151_admin";
$password   = "C0ntrasenPassword@";
$dbname     = "u605613151_sistema_academ";

$conn = new mysqli($servername, $username, $password, $dbname);
$conn->set_charset("utf8mb4");

// Inputs
$rol      = isset($_POST['rol'])      ? trim($_POST['rol'])      : '';
$usuario  = isset($_POST['usuario'])  ? trim($_POST['usuario'])  : '';
$pwdPlain = isset($_POST['password']) ? trim($_POST['password']) : '';

if ($rol === '' || $usuario === '' || $pwdPlain === '') {
  http_response_code(400);
  echo json_encode(['ok'=>false,'error'=>'FALTAN_DATOS']); exit;
}

$rol = strtoupper($rol);
if (!in_array($rol, ['ESTUDIANTE','DOCENTE'], true)) {
  http_response_code(403);
  echo json_encode(['ok'=>false,'error'=>'ROL_NO_PERMITIDO']); exit;
}

try {
  if ($rol === 'DOCENTE') {
    // DOCENTE: email + password + usuario ACTIVO + docente ACTIVO
    $email = mb_strtolower($usuario, 'UTF-8');
    $sql = "
      SELECT u.id_Usuario, u.estado_usuario,
             p.nombre AS nombre, p.apellido AS apellido,
             d.id_Docente AS id_docente, u.email
      FROM usuario u
      JOIN docente d ON d.id_Docente = u.id_Usuario
      JOIN persona p ON p.id_Persona = u.id_Usuario
      WHERE u.email = ?
        AND u.password = ?
        AND UPPER(u.estado_usuario) = 'ACTIVO'
        AND UPPER(d.estado) = 'ACTIVO'
      LIMIT 1
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $email, $pwdPlain);

  } else {
    // ESTUDIANTE: nro_registro + password + usuario ACTIVO
    // (CAMBIO) Traemos nombre y apellido desde persona
    $sql = "
      SELECT u.id_Usuario, u.estado_usuario,
             p.nombre AS nombre, p.apellido AS apellido
      FROM estudiante e
      JOIN usuario u ON u.id_Usuario = e.id_Estudiante
      JOIN persona p ON p.id_Persona = u.id_Usuario
      WHERE e.nro_registro = ?
        AND u.password = ?
        AND UPPER(u.estado_usuario) = 'ACTIVO'
      LIMIT 1
    ";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $usuario, $pwdPlain);
  }

  $stmt->execute();
  $res = $stmt->get_result();

  if ($res && $res->num_rows === 1) {
    $redirect = ($rol === 'DOCENTE')
      ? '/Pagina_web/html/docente.html'
      : '/Pagina_web/html/estudiantes.html';

    $payload = ['ok'=>true,'rol'=>$rol,'redirect'=>$redirect];

    $row = $res->fetch_assoc();
    if ($rol === 'ESTUDIANTE') {
      $payload['nombre']   = $row['nombre']   ?? '';
      $payload['apellido'] = $row['apellido'] ?? '';
    } else if ($rol === 'DOCENTE') {
      $payload['docente'] = [
        'id_docente' => $row['id_docente'],
        'nombre'     => $row['nombre'],
        'apellido'   => $row['apellido'],
        'email'      => $row['email']
      ];
    }

    http_response_code(200);
    echo json_encode($payload);

  } else {
    // Puede ser credencial inválida o estado no ACTIVO
    http_response_code(401);
    echo json_encode(['ok'=>false,'error'=>'CREDENCIALES_INVALIDAS_O_INACTIVO']);
  }

  $stmt->close();
  $conn->close();

} catch (Throwable $e) {
  http_response_code(500);
  echo json_encode(['ok'=>false,'error'=>'SERVER_ERROR','msg'=>$e->getMessage()]);
}
