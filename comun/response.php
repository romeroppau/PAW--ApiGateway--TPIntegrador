<?php

class Response
{
    public static function json(
        array $data,
        int $status = 200
    ): void {
        http_response_code($status);
        header('Content-Type: application/json; charset=utf-8');

        try {
            echo json_encode(
                $data,
                JSON_UNESCAPED_UNICODE | JSON_THROW_ON_ERROR
            );
        } catch (JsonException $error) {
            http_response_code(500);

            echo '{"error":"Ocurrió un error interno del servidor","campos":{}}';
        }
    }

    public static function error(
        string $mensaje,
        int $status,
        array $campos = []
    ): void {
        self::json([
            'error' => $mensaje,
            'campos' => (object) $campos
        ], $status);
    }
}
