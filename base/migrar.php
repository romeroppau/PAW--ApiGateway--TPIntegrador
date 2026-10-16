<?php
declare(strict_types=1);

function variableObligatoria(string $nombre): string
{
    $valor = getenv($nombre);

    if ($valor === false || trim($valor) === '') {
        throw new RuntimeException("Falta configurar {$nombre}");
    }

    return $valor;
}

function validarNombreBase(string $base): string
{
    if (!preg_match('/^[A-Za-z0-9_]+$/', $base)) {
        throw new RuntimeException('DB_NAME tiene un formato inválido');
    }

    return $base;
}

function separarSentencias(string $sql): array
{
    $sentencias = [];
    $actual = '';
    $comillas = null;
    $comentarioLinea = false;
    $comentarioBloque = false;
    $longitud = strlen($sql);

    for ($i = 0; $i < $longitud; $i++) {
        $caracter = $sql[$i];
        $siguiente = $sql[$i + 1] ?? '';

        if ($comentarioLinea) {
            if ($caracter === "\n") {
                $comentarioLinea = false;
                $actual .= "\n";
            }
            continue;
        }

        if ($comentarioBloque) {
            if ($caracter === '*' && $siguiente === '/') {
                $comentarioBloque = false;
                $actual .= ' ';
                $i++;
            }
            continue;
        }

        if ($comillas !== null) {
            $actual .= $caracter;

            if ($caracter === '\\' && $comillas !== '`' && $i + 1 < $longitud) {
                $actual .= $sql[++$i];
                continue;
            }

            if ($caracter === $comillas) {
                if ($siguiente === $comillas) {
                    $actual .= $sql[++$i];
                } else {
                    $comillas = null;
                }
            }
            continue;
        }

        if ($caracter === "'" || $caracter === '"' || $caracter === '`') {
            $comillas = $caracter;
            $actual .= $caracter;
            continue;
        }

        if ($caracter === '#') {
            $comentarioLinea = true;
            continue;
        }

        if (
            $caracter === '-'
            && $siguiente === '-'
            && (($sql[$i + 2] ?? '') === '' || ctype_space($sql[$i + 2]))
        ) {
            $comentarioLinea = true;
            $i++;
            continue;
        }

        if ($caracter === '/' && $siguiente === '*') {
            $comentarioBloque = true;
            $i++;
            continue;
        }

        if ($caracter === ';') {
            if (trim($actual) !== '') {
                $sentencias[] = trim($actual);
            }
            $actual = '';
            continue;
        }

        $actual .= $caracter;
    }

    if ($comillas !== null || $comentarioBloque) {
        throw new RuntimeException('Hay comillas o comentarios sin cerrar en un SQL');
    }

    if (trim($actual) !== '') {
        $sentencias[] = trim($actual);
    }

    return $sentencias;
}

function ejecutarSql(PDO $pdo, string $sql): void
{
    foreach (separarSentencias($sql) as $sentencia) {
        $pdo->exec($sentencia);
    }
}

try {
    $host = variableObligatoria('DB_HOST');
    $puerto = variableObligatoria('DB_PORT');
    $base = validarNombreBase(variableObligatoria('DB_NAME'));
    $usuarioAdmin = variableObligatoria('DB_ADMIN_USER');
    $claveAdmin = variableObligatoria('DB_ADMIN_PASSWORD');
    $claveBackend = variableObligatoria('BACKEND_DB_PASSWORD');
    $claveInventario = variableObligatoria('INVENTARIO_DB_PASSWORD');

    if (!ctype_digit($puerto) || (int) $puerto < 1 || (int) $puerto > 65535) {
        throw new RuntimeException('DB_PORT no es un puerto válido');
    }

    if (in_array(strtolower($usuarioAdmin), ['backend', 'inventario'], true)) {
        throw new RuntimeException('La migración debe usar el usuario administrador de MySQL');
    }

    $certificado = getenv('DB_SSL_CA') ?: '';
    $hostsLocales = ['localhost', '127.0.0.1', '::1', 'db'];
    $esLocal = in_array(strtolower($host), $hostsLocales, true);

    $opciones = [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
        PDO::MYSQL_ATTR_MULTI_STATEMENTS => false,
    ];

    if ($certificado !== '') {
        if (!is_readable($certificado)) {
            throw new RuntimeException('No se puede leer el archivo indicado por DB_SSL_CA');
        }

        $opciones[PDO::MYSQL_ATTR_SSL_CA] = $certificado;
        $opciones[PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT] = true;
    } elseif (!$esLocal) {
        throw new RuntimeException('Para conectarse a una base remota hace falta DB_SSL_CA');
    }

    $dsn = sprintf(
        'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
        $host,
        $puerto,
        $base
    );

    $pdo = new PDO($dsn, $usuarioAdmin, $claveAdmin, $opciones);

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

    $sqlPermisos = file_get_contents(__DIR__ . '/permisos.sql');
    if ($sqlPermisos === false) {
        throw new RuntimeException('No se pudo leer base/permisos.sql');
    }

    if (!str_contains($sqlPermisos, '{{DB_NAME}}')) {
        throw new RuntimeException('Falta {{DB_NAME}} en base/permisos.sql');
    }

    $sqlPermisos = str_replace('{{DB_NAME}}', '`' . $base . '`', $sqlPermisos);

    $pdo->exec(
    "CREATE USER IF NOT EXISTS 'backend'@'%' IDENTIFIED BY "
    . $pdo->quote($claveBackend)
);

$pdo->exec(
    "ALTER USER 'backend'@'%' IDENTIFIED BY "
    . $pdo->quote($claveBackend)
);

$pdo->exec(
    "CREATE USER IF NOT EXISTS 'inventario'@'%' IDENTIFIED BY "
    . $pdo->quote($claveInventario)
);

$pdo->exec(
    "ALTER USER 'inventario'@'%' IDENTIFIED BY "
    . $pdo->quote($claveInventario)
);

    ejecutarSql($pdo, $sqlPermisos);

    echo "Migraciones y permisos listos para {$base}.\n";

    foreach (['backend', 'inventario'] as $usuario) {
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