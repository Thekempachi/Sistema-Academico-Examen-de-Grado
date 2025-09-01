<?php
// Datos de conexión
$host     = "localhost"; // o 127.0.0.1 según configuración
$dbname   = "u605613151_sistema_academ";
$user     = "u605613151_admin";
$password = "C0ntrasenPassword@";

try {
    // Conexión con PDO
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $user, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

    // Datos a insertar
    $ci              = "456117";
    $nombre          = "Hector";
    $apellido        = "Palacios";
    $fecha_nacimiento= "1990-01-01"; // ejemplo, pon la fecha que quieras
    $sexo            = "M";

    // Llamada al procedimiento con parámetros OUT
    $stmt = $pdo->prepare("CALL Insertar_Persona(:ci, :nombre, :apellido, :fecha_nacimiento, :sexo, @out_id, @out_status)");
    $stmt->execute([
        ':ci'              => $ci,
        ':nombre'          => $nombre,
        ':apellido'        => $apellido,
        ':fecha_nacimiento'=> $fecha_nacimiento,
        ':sexo'            => $sexo
    ]);

    // Recuperar resultados OUT
    $res = $pdo->query("SELECT @out_id AS id_persona, @out_status AS status")->fetch(PDO::FETCH_ASSOC);

    $idPersona = $res['id_persona'];
    $status    = $res['status'];

    // Mostrar en pantalla
    if ($status === 'OK') {
        echo "✅ Persona insertada correctamente con ID: " . $idPersona;
    } else {
        echo "⚠️ Error: " . $status;
    }

} catch (PDOException $e) {
    echo "❌ Error de conexión o SQL: " . $e->getMessage();
}
?>
