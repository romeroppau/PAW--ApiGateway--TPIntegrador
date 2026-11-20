<?php
declare(strict_types=1);

// Carga los datos semilla (datos de prueba) de base/semillas/NNN_*.sql.
// A diferencia de las migraciones, se corren TODOS cada vez y no se anotan: así vuelven
// a dejar los datos de prueba como estaban (por ejemplo, el stock vuelve al valor inicial).
// Nunca en producción: solo acepta ENTORNO=local, dev o ci.
//
// Con el argumento "volumen" (php base/sembrar.php volumen) carga en cambio el juego de datos en
// cantidad de base/semillas-volumen/ (muchos clientes, turnos de meses, compras, avisos...), para
// ver cómo escalan las pantallas. Ese juego va aparte porque la prueba de humo depende de que las
// semillas sean exactamente las de base/semillas/: solo se carga a mano, en local o en dev (nunca
// en el CI). Necesita que antes estén cargadas las semillas comunes.

require_once __DIR__ . '/funciones.php';

try {
    $volumen = ($argv[1] ?? '') === 'volumen';
    $carpeta = $volumen ? 'semillas-volumen' : 'semillas';
    $permitidos = $volumen ? ['local', 'dev'] : ['local', 'dev', 'ci'];

    // 1. Lo más importante: negarse a correr en producción (y el volumen, tampoco en el CI).
    $entorno = variableObligatoria('ENTORNO');
    if (!in_array($entorno, $permitidos, true)) {
        throw new RuntimeException("Las semillas de base/{$carpeta}/ no se cargan en el entorno '{$entorno}'");
    }

    // 2. Conectarse como administrador.
    $pdo = conectarComoAdministrador();

    // 3. Todos los archivos de semillas, en orden (001, 002, ...).
    $archivos = glob(__DIR__ . "/{$carpeta}/[0-9][0-9][0-9]_*.sql") ?: [];
    sort($archivos, SORT_STRING);

    if ($archivos === []) {
        throw new RuntimeException("No se encontraron archivos base/{$carpeta}/NNN_*.sql");
    }

    foreach ($archivos as $ruta) {
        $nombre = basename($ruta);

        $contenido = file_get_contents($ruta);
        if ($contenido === false) {
            throw new RuntimeException("No se pudo leer base/{$carpeta}/{$nombre}");
        }

        ejecutarSql($pdo, $contenido);

        // 4. Mostrar qué cargó.
        echo "Semilla aplicada: {$carpeta}/{$nombre}\n";
    }

    echo ($volumen ? 'Datos en cantidad listos' : 'Datos semilla listos') . " (entorno {$entorno}).\n";
} catch (Throwable $error) {
    fwrite(STDERR, "Fallaron las semillas: {$error->getMessage()}\n");
    exit(1);
}
