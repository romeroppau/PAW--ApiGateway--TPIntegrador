<?php

class Request
{
    public static function method(): string //PHP recibe información sobre la petición en la variable especial $_SERVER. Dentro de ella, REQUEST_METHOD contiene el método HTTP.
    //El operador ?? significa que, si esa posición no existe o es null, usamos el valor de la derecha. En este ejemplo, el valor alternativo es GET.
    {
        return $_SERVER['REQUEST_METHOD'] ?? 'GET';
    }
    public static function path(): string
    {
        $uri = $_SERVER['REQUEST_URI'] ?? '/'; //REQUEST_URI puede contener la ruta y los parámetros de consulta
        return parse_url($uri, PHP_URL_PATH) ?? '/'; //con parse, obtenemos solamente la ruta, sin parametros
    }

    public static function query(): array
    {
        return $_GET; //PHP guarda los parámetros de la URL en $_GET, incluso cuando la petición HTTP usa otro método, como POST
    }

    public static function json(): array //para poder leer el cuerpo JSON, por ejemplo de los datos del usuario que intenta iniciarse
    { //Lee el contenido enviado en la solicitud, intenta interpretarlo como JSON 
    //y devuelve un array de PHP para que el módulo pueda trabajar con esos datos
        $body = file_get_contents('php://input');
        if ($body === '') {
            return [];
        }
        $data = json_decode($body, true);
        if (!is_array($data)) {
            Response::json([
                'error' => 'El cuerpo de la solicitud no contiene un JSON válido'
            ], 400);

            exit;
        }
        return $data;
    }

}


