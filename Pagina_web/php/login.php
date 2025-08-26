<?php
// Configuración de la base de datos
$servername = "localhost";
$username = "u605613151_Admin";
$password = "Blefast123*";
$dbname = "u605613151_sistema_academ";

// Crear conexión
$conn = new mysqli($servername, $username, $password, $dbname);

// Verificar conexión
if ($conn->connect_error) {
    die("Conexión fallida: " . $conn->connect_error);
}

// Obtener datos del formulario
$nombre = $_POST['nombre'];
$password = $_POST['password'];

// Consulta para verificar credenciales
$sql = "SELECT p.* FROM Persona p 
        INNER JOIN Usuario u ON p.id = u.persona_id 
        WHERE p.nombre = ? AND u.password = ?";
$stmt = $conn->prepare($sql);
$stmt->bind_param("ss", $nombre, $password);
$stmt->execute();
$result = $stmt->get_result();

if ($result->num_rows > 0) {
    // Login exitoso
    session_start();
    $_SESSION['loggedin'] = true;
    $_SESSION['nombre'] = $nombre;
    
    echo "Login exitoso. Bienvenido " . $nombre;
    // Aquí puedes redirigir a otra página: header("Location: dashboard.php");
} else {
    // Login fallido
    echo "Nombre de usuario o contraseña incorrectos.";
}

$stmt->close();
$conn->close();
?>