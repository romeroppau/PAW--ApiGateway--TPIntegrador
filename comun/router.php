<?php

class Router
{
    private array $routes = [];

    // Registra una ruta para un método HTTP.
    private function registrar(
        string $method,
        string $path,
        callable $handler
    ): void {
        $this->routes[$method][$path] = $handler;
    }

    public function get(string $path, callable $handler): void
    {
        $this->registrar('GET', $path, $handler);
    }

    public function post(string $path, callable $handler): void
    {
        $this->registrar('POST', $path, $handler);
    }

    public function put(string $path, callable $handler): void
    {
        $this->registrar('PUT', $path, $handler);
    }

    public function delete(string $path, callable $handler): void
    {
        $this->registrar('DELETE', $path, $handler);
    }

    public function dispatch(string $method, string $path): void
    {
        $rutaEncontrada = false;

        foreach ($this->routes as $metodo => $rutas) {
            foreach ($rutas as $ruta => $handler) {

                $parametros = [];
                $patron = preg_quote($ruta, '#');

                $patron = preg_replace_callback(
                    '/\\\\\{([a-zA-Z_][a-zA-Z0-9_]*)\\\\\}/',
                    function ($coincidencia) use (&$parametros) {
                        $parametros[] = $coincidencia[1];

                        return '([^/]+)';
                    },
                    $patron
                );

                if (!preg_match('#^' . $patron . '$#', $path, $coincidencias)) {
                    continue;
                }

                $rutaEncontrada = true;

                if ($metodo !== $method) {
                    continue;
                }

                array_shift($coincidencias);

                $valores = [];

                foreach ($parametros as $indice => $nombre) {
                    $valores[$nombre] = $coincidencias[$indice];
                }

                $handler($valores);
                return;
            }
        }

        if ($rutaEncontrada) {
            Response::json([
                'error' => 'Método HTTP no permitido'
            ], 405);
            return;
        }

        Response::json([
            'error' => 'Recurso no encontrado'
        ], 404);
    }
}