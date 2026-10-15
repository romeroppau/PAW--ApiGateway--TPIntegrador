
<?php

class Router
{
    private array $routes = []; //es un array donde vamos a guardar las rutas registradas. 
    //el router guarda una asociación entre un método, una ruta y la funcion que debe ejecutarse
    public function get(string $path, callable $handler): void //este metodo registra una ruta GET
    {
        $this->routes['GET'][$path] = $handler;
    }

    public function dispatch(string $method, string $path): void //dispatch recibe el metodo y la ruta que obtuvimos mediante request.php
    //busca si existe coincidencia, si la encuentra, ejecuta la funcion asociada $handler()
    {
        if (isset($this->routes[$method][$path])) {
            $handler = $this->routes[$method][$path];

            $handler();
            return;
        }

        Response::json([//si no la encuentra, responde con el error
            'error' => 'Recurso no encontrado'
        ], 404);
    }
}
