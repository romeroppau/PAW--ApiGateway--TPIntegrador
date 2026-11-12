<?php
declare(strict_types=1);

require_once __DIR__ . '/funciones.php';


try {
    $base = validarNombreBase(variableObligatoria('DB_NAME'));
    $usuarioAdmin = variableObligatoria('DB_ADMIN_USER');
    // Un usuario de MySQL por módulo, cada uno con su contraseña (SEGURIDAD.md).
    // Para sumar un módulo: agregarlo acá y pasar su variable al migrador en compose.yaml.
    $usuariosModulos = [
        'backend' => variableObligatoria('BACKEND_DB_PASSWORD'),
        'inventario' => variableObligatoria('INVENTARIO_DB_PASSWORD'),
        'pacientes' => variableObligatoria('PACIENTES_DB_PASSWORD'),
        'adopciones' => variableObligatoria('ADOPCIONES_DB_PASSWORD'),
    ];

    if (array_key_exists(strtolower($usuarioAdmin), $usuariosModulos)) {
        throw new RuntimeException('La migración debe usar el usuario administrador de MySQL');
    }

    $pdo = conectarComoAdministrador();

    $pdo->exec(
        'CREATE TABLE IF NOT EXISTS migracion (
            archivo VARCHAR(255) NOT NULL,
            aplicada_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (archivo)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4'
    );

    $archivos = glob(__DIR__ . '/[0-9][0-9][0-9]_*.sql') ?: [];
    sort($archivos, SORT_STRING);

    if ($archivos === []) {
        throw new RuntimeException('No se encontraron archivos base/NNN_*.sql');
    }

    $buscar = $pdo->prepare('SELECT 1 FROM migracion WHERE archivo = :archivo');
    $anotar = $pdo->prepare('INSERT INTO migracion (archivo) VALUES (:archivo)');

    foreach ($archivos as $ruta) {
        $nombre = basename($ruta);
        $buscar->execute(['archivo' => $nombre]);

        if ($buscar->fetchColumn() !== false) {
            echo "Ya aplicada: {$nombre}\n";
            continue;
        }

        $contenido = file_get_contents($ruta);
        if ($contenido === false) {
            throw new RuntimeException("No se pudo leer {$nombre}");
        }

        ejecutarSql($pdo, $contenido);
        $anotar->execute(['archivo' => $nombre]);

        echo "Aplicada: {$nombre}\n";
    }

    // Los usuarios se crean (o se les vuelve a asignar la contraseña) antes de los permisos:
    // un GRANT a un usuario que no existe da error.
    foreach ($usuariosModulos as $usuario => $clave) {
        $pdo->exec("CREATE USER IF NOT EXISTS '{$usuario}'@'%' IDENTIFIED BY " . $pdo->quote($clave));
        $pdo->exec("ALTER USER '{$usuario}'@'%' IDENTIFIED BY " . $pdo->quote($clave));
    }

    // Permisos: un archivo por migración, con el mismo nombre (base/permisos/NNN_*.sql).
    // Así cada rama agrega su propio archivo y nadie edita un archivo compartido.
    // Se corren todos cada vez: repetir un GRANT no rompe nada.
    $archivosPermisos = glob(__DIR__ . '/permisos/[0-9][0-9][0-9]_*.sql') ?: [];
    sort($archivosPermisos, SORT_STRING);

    foreach ($archivosPermisos as $ruta) {
        $nombre = basename($ruta);

        // Un GRANT sobre una tabla que no existe da error: los permisos solo acompañan a su migración.
        if (!is_file(__DIR__ . '/' . $nombre)) {
            throw new RuntimeException("base/permisos/{$nombre} no tiene su migración base/{$nombre}");
        }

        $sqlPermisos = file_get_contents($ruta);
        if ($sqlPermisos === false) {
            throw new RuntimeException("No se pudo leer base/permisos/{$nombre}");
        }

        if (!str_contains($sqlPermisos, '{{DB_NAME}}')) {
            throw new RuntimeException("Falta {{DB_NAME}} en base/permisos/{$nombre}");
        }

        ejecutarSql($pdo, str_replace('{{DB_NAME}}', '`' . $base . '`', $sqlPermisos));
        echo "Permisos aplicados: {$nombre}\n";
    }

    echo "Migraciones y permisos listos para {$base}.\n";

    foreach (array_keys($usuariosModulos) as $usuario) {
        $grants = $pdo->query("SHOW GRANTS FOR '{$usuario}'@'%'")
            ->fetchAll(PDO::FETCH_COLUMN);

        echo "\nPermisos de {$usuario}:\n";
        foreach ($grants as $grant) {
            echo "  {$grant}\n";
        }
    }
} catch (Throwable $error) {
    fwrite(STDERR, "Falló la migración: {$error->getMessage()}\n");
    exit(1);
}