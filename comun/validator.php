
<?php

class Validator
{
    public static function requerido( //comprueba que un campo exista, que no sea null y no esté vacío ni contenga solamente espacios
        array $datos,
        string $campo
    ): bool {
        return isset($datos[$campo])
            && trim((string) $datos[$campo]) !== '';
    }

    public static function emailValido(string $email): bool //comprueba formato de mail valido
    {
        return filter_var(
            $email,
            FILTER_VALIDATE_EMAIL
        ) !== false;
    }

    public static function longitudMinima(
        string $valor,
        int $minimo
    ): bool {
        return mb_strlen($valor, 'UTF-8') >= $minimo;
    }
}
