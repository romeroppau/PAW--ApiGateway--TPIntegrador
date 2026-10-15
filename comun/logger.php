
<?php
class Logger
{
    public static function info(string $mensaje): void //registra informacion sobre un evento normal
    {
        error_log('[INFO] ' . $mensaje);
    }

    public static function error(string $mensaje): void //registra un problema o error
    {
        error_log('[ERROR] ' . $mensaje);
    }
}
