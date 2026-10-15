<?php

require_once __DIR__ . '/response.php';
require_once __DIR__ . '/request.php';
require_once __DIR__ . '/router.php';
require_once __DIR__ . '/logger.php';

$router = new Router();

$router->get('/api/gateway/salud', function () {
    Response::json([
        'estado' => 'funciona',
        'modulo' => 'ApiGateway'
    ]);
});


try {
    $router->dispatch(
        Request::method(),
        Request::path()
    );
} catch (Throwable $error) {
    Logger::error(
        'Error inesperado: ' . get_class($error)
    );

    Response::error(
        'Ocurrió un error interno del servidor',
        500
    );
}
