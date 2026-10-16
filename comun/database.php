<?php

class Database //esta clase se apoya en config.php. solamente pide los datos que necesita
{
    private static ?PDO $conexion = null;

    public static function conectar(): PDO //solicita conexión con MySQL. PDO es la herramienta de PHP que permite
    //conectarse a una bd y ejecutar consultas
    {
        if (self::$conexion !== null) {
            return self::$conexion;
        }

        $host = Config::get('DB_HOST');
        $puerto = Config::get('DB_PORT') ?: '3306';
        $nombre = Config::get('DB_NAME');
        $usuario = Config::get('DB_USER');
        $password = Config::get('DB_PASSWORD');
        $certificado = Config::get('DB_SSL_CA');

        if (
            !$host
            || !$nombre
            || !$usuario
            || $password === null
            || !$certificado
        ) {
            throw new RuntimeException(
                'Falta configurar la conexión segura a la base de datos'
            );
        }

        if (!is_readable($certificado)) {
            throw new RuntimeException(
                'No está disponible el certificado de la base de datos'
            );
        }

        $dsn = "mysql:host=$host;port=$puerto;dbname=$nombre;charset=utf8mb4";

        self::$conexion = new PDO(
            $dsn,
            $usuario,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
                PDO::MYSQL_ATTR_SSL_CA => $certificado,
                PDO::MYSQL_ATTR_SSL_VERIFY_SERVER_CERT => true
            ]
        );

        return self::$conexion;
    }
}

