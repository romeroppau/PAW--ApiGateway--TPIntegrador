
<?php
class Database //esta clase se apoya en config.php. solamente pide los datos que necesita
{
    private static ?PDO $conexion = null;

    public static function conectar(): PDO //solicita conexión con MySQL. PDO es la herramienta de PHP que permite
    //conectarse a una bd y ejecutar consultas
    {
        if (self::$conexion !== null) { //guarda conexión para reutilizarla dentro del mismo proceso
            return self::$conexion;
        }

        $host = Config::get('DB_HOST');
        $nombre = Config::get('DB_NAME');
        $usuario = Config::get('DB_USER');
        $password = Config::get('DB_PASSWORD');

        if (!$host || !$nombre || !$usuario || $password === null) {
            throw new RuntimeException(
                'Falta configurar la conexión a la base de datos'
            );
        }

        $dsn = "mysql:host=$host;dbname=$nombre;charset=utf8mb4";

        self::$conexion = new PDO(
            $dsn,
            $usuario,
            $password,
            [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,//permite que los errores de la bd se comuniquen mediante excepciones
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,//hace que resultados de las consultas se devuelvan como arrays asociativos
                PDO::ATTR_EMULATE_PREPARES => false //desactiva la emulación de consultas preparadas de PDO para MySQL
            ]
        );

        return self::$conexion;
    }
}
