<?php

// Lectura de los parámetros que la veterinaria cambia desde su panel (tabla configuracion,
// migración 014). Solo lee: los escribe y los valida Backend (PUT /api/configuracion).
//
// Cada módulo pasa su valor por defecto (el que usaba antes de que existiera la configuración).
// Se usa ese valor si la clave no está guardada, si la tabla todavía no existe (por ejemplo, en un
// entorno sin la migración 014) o si lo guardado no tiene la forma esperada. Así el sistema sigue
// andando igual que antes aunque falte algo.
//
// Uso:  $limite = Configuracion::entero('limite_stock_bajo', 10, 0, 1000);
//       $apertura = Configuracion::hora('hora_apertura', '08:00');
class Configuracion
{
    // Toda la tabla, leída una vez por pedido (son pocas filas).
    private static ?array $valores = null;

    public static function entero(string $clave, int $defecto, int $minimo, int $maximo): int
    {
        $valor = self::valores()[$clave] ?? null;

        if (!is_string($valor) || !preg_match('/^\d{1,9}$/', $valor)) {
            return $defecto;
        }

        $numero = (int) $valor;

        return $numero >= $minimo && $numero <= $maximo ? $numero : $defecto;
    }

    // Una hora "HH:MM" de 24 horas.
    public static function hora(string $clave, string $defecto): string
    {
        $valor = self::valores()[$clave] ?? null;

        return is_string($valor) && preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $valor) ? $valor : $defecto;
    }

    // Para las pruebas: olvida lo leído (o carga valores sin base de datos).
    public static function reiniciar(?array $valores = null): void
    {
        self::$valores = $valores;
    }

    private static function valores(): array
    {
        if (self::$valores !== null) {
            return self::$valores;
        }

        try {
            $filas = Database::conectar()->query('SELECT clave, valor FROM configuracion')->fetchAll(PDO::FETCH_KEY_PAIR);
            self::$valores = is_array($filas) ? $filas : [];
        } catch (Throwable $error) {
            Logger::error('No se pudo leer la configuración (se usan los valores por defecto): ' . $error->getMessage());
            self::$valores = [];
        }

        return self::$valores;
    }
}
