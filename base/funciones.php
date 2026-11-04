<?php
declare(strict_types=1);

// Funciones que usan migrar.php (migraciones) y sembrar.php (datos semilla).
// Están acá para no repetir el mismo código en los dos archivos.

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


// Se conecta a la base como administrador (DB_ADMIN_USER), con SSL si hay certificado.
// Lo usan el migrador y el sembrador.
function conectarComoAdministrador(): PDO
{
    $host = variableObligatoria('DB_HOST');
    $puerto = variableObligatoria('DB_PORT');
    $base = validarNombreBase(variableObligatoria('DB_NAME'));
    $usuarioAdmin = variableObligatoria('DB_ADMIN_USER');
    $claveAdmin = variableObligatoria('DB_ADMIN_PASSWORD');

    if (!ctype_digit($puerto) || (int) $puerto < 1 || (int) $puerto > 65535) {
        throw new RuntimeException('DB_PORT no es un puerto válido');
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

    return new PDO($dsn, $usuarioAdmin, $claveAdmin, $opciones);
}
