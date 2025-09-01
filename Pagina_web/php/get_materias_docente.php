<?php
// Pagina_web/php/get_materias_docente.php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// Conexión manual
$host     = "localhost";
$dbname   = "u605613151_sistema_academ";
$user     = "u605613151_admin";
$password = "C0ntrasenPassword@";
$conn = new mysqli($host, $user, $password, $dbname);
$conn->set_charset("utf8mb4");

// Solo por GET (para frontend local sin sesión)
$email = isset($_GET['email']) ? $_GET['email'] : null;
if (!$email) {
    echo json_encode(['ok'=>false, 'error'=>'NO_EMAIL']);
    exit;
}

// 1. Obtener datos del docente
$sql_docente = "SELECT d.id_Docente, p.nombre, p.apellido, d.certificacion, p.email
FROM docente d
JOIN usuario u ON u.id_Usuario = d.id_Docente
JOIN persona p ON p.id_Persona = d.id_Docente
WHERE u.email = ?";
$stmt = $conn->prepare($sql_docente);
$stmt->bind_param('s', $email);
$stmt->execute();
$res = $stmt->get_result();
$docente = $res->fetch_assoc();
if (!$docente) {
    echo json_encode(['ok'=>false, 'error'=>'DOCENTE_NOT_FOUND']);
    exit;
}
$id_docente = $docente['id_Docente'];

// 2. Obtener materias asignadas al docente
$sql_materias = "SELECT om.id_Oferta_Materia, m.sigla, m.codigo, m.id_Materia, m.sigla AS materia_sigla, m.codigo AS materia_codigo, m.nombre AS nombre, om.grupo, om.cupos, om.estado, a.codigo AS aula_codigo, a.descripcion AS aula_desc
FROM oferta_materia om
JOIN materia m ON m.id_Materia = om.id_Materia
LEFT JOIN aula a ON a.id_Aula = om.id_Aula
WHERE om.id_Docente = ?";
$stmt2 = $conn->prepare($sql_materias);
$stmt2->bind_param('i', $id_docente);
$stmt2->execute();
$res2 = $stmt2->get_result();
$materias = [];
while ($mat = $res2->fetch_assoc()) {
    $materia = $mat;
    $materia['estudiantes'] = [];
    // 3. Obtener estudiantes inscritos en la materia
    $sql_est = "SELECT e.id_Estudiante, p.nombre, p.apellido, e.nro_registro, u.email
    FROM registro_materia rm
    JOIN estudiante e ON e.id_Estudiante = rm.id_Estudiante
    JOIN persona p ON p.id_Persona = e.id_Estudiante
    JOIN usuario u ON u.id_Usuario = e.id_Estudiante
    WHERE rm.id_Oferta_Materia = ? AND rm.estado = 'REGISTRADO'";
    $stmt3 = $conn->prepare($sql_est);
    $stmt3->bind_param('i', $mat['id_Oferta_Materia']);
    $stmt3->execute();
    $res3 = $stmt3->get_result();
    while ($est = $res3->fetch_assoc()) {
        $materia['estudiantes'][] = $est;
    }
    $materias[] = $materia;
}

// 4. Respuesta
$response = [
    'ok' => true,
    'docente' => [
        'nombre' => $docente['nombre'],
        'apellido' => $docente['apellido'],
        'email' => $docente['email'],
        'certificacion' => $docente['certificacion']
    ],
    'materias' => $materias
];
echo json_encode($response);
