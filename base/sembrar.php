<?php
declare(strict_types=1);

// Carga los datos semilla (datos de prueba) de base/semillas/NNN_*.sql.
// A diferencia de las migraciones, se corren TODOS cada vez y no se anotan: así vuelven
// a dejar los datos de prueba como estaban (por ejemplo, el stock vuelve al valor inicial).
// Nunca en producción: solo acepta ENTORNO=local, dev o ci.

require_once __DIR__ . '/funciones.php';

try {
    // 1. Lo más importante: negarse a correr en producción.
    $entorno = variableObligatoria('ENTORNO');
    if (!in_array($entorno, ['local', 'dev', 'ci'], true)) {
        throw new RuntimeException("Las semillas no se cargan en el entorno '{$entorno}'");
    }

    // 2. Conectarse como administrador.
    $pdo = conectarComoAdministrador();

    // 3. Todos los archivos de semillas, en orden (001, 002, ...).
    $archivos = glob(__DIR__ . '/semillas/[0-9][0-9][0-9]_*.sql') ?: [];
    sort($archivos, SORT_STRING);

    if ($archivos === []) {
        throw new RuntimeException('No se encontraron archivos base/semillas/NNN_*.sql');
    }

    foreach ($archivos as $ruta) {
        $nombre = basename($ruta);

        $contenido = file_get_contents($ruta);
        if ($contenido === false) {
            throw new RuntimeException("No se pudo leer base/semillas/{$nombre}");
        }

        ejecutarSql($pdo, $contenido);

        // 4. Mostrar qué cargó.
        echo "Semilla aplicada: {$nombre}\n";
    }

    echo "Datos semilla listos (entorno {$entorno}).\n";
} catch (Throwable $error) {
    fwrite(STDERR, "Fallaron las semillas: {$error->getMessage()}\n");
    exit(1);
}
