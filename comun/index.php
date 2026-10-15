<?php
require_once __DIR__ . '/Response.php';
require_once __DIR__ . '/Request.php';

Response::json([
    'metodo' => Request::method(),
    'ruta' => Request::path(),
    'parametros' => Request::query()
]);
