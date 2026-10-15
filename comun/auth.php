<?php

class Auth
{
    private const COOKIE_SESION = 'huellavet_sesion';

    public static function usuarioActual(): ?array
    {
        $token = $_COOKIE[self::COOKIE_SESION] ?? null;

        if (!is_string($token) || $token === '') {
            return null;
        }

        $partes = explode('.', $token);

        if (count($partes) !== 3) {
            return null;
        }

        [$cabecera, $payload, $firma] = $partes;

        $datosCabecera = self::decodificarJson($cabecera);
        $datosUsuario = self::decodificarJson($payload);
        $firmaBinaria = self::decodificarBase64Url($firma);

        if (
            $datosCabecera === null
            || ($datosCabecera['alg'] ?? null) !== 'RS256'
            || $datosUsuario === null
            || $firmaBinaria === null
        ) {
            return null;
        }

        $clavePublica = Config::get('JWT_PUBLIC_KEY');

        if ($clavePublica === null || $clavePublica === '') {
            Logger::error(
                'No está configurada la clave pública JWT'
            );
            return null;
        }

        $clavePublica = str_replace(
            '\\n',
            "\n",
            $clavePublica
        );

        $clave = openssl_pkey_get_public($clavePublica);

        if ($clave === false) {
            Logger::error(
                'No se pudo cargar la clave pública JWT'
            );
            return null;
        }

        $resultado = openssl_verify(
            $cabecera . '.' . $payload,
            $firmaBinaria,
            $clave,
            OPENSSL_ALGO_SHA256
        );

        if ($resultado !== 1) {
            return null;
        }

        if (
            !isset($datosUsuario['exp'])
            || !is_numeric($datosUsuario['exp'])
            || (int) $datosUsuario['exp'] <= time()
            || !isset($datosUsuario['id'])
            || !is_string($datosUsuario['rol'])
            || $datosUsuario['rol'] === ''
        ) {
            return null;
        }

        return $datosUsuario;
    }

    public static function requerirRol(array $roles = []): array
    {
        $usuario = self::usuarioActual();

        if ($usuario === null) {
            Response::error('No autenticado', 401);
            exit;
        }

        if (
            $roles !== []
            && !in_array($usuario['rol'], $roles, true)
        ) {
            Response::error(
                'No tiene permisos para realizar esta operación',
                403
            );
            exit;
        }

        return $usuario;
    }

    public static function verificarCsrf(array $usuario): void
    {
        $metodo = Request::method();

        if (!in_array($metodo, ['POST', 'PUT', 'DELETE'], true)) {
            return;
        }

        /*
         * PENDIENTE:
         * El equipo debe definir cómo se obtiene el token CSRF
         * esperado. El JWT acordado contiene id, rol y exp,
         * por lo que no podemos obtenerlo de ese token.
         *
         * Hasta definir el mecanismo, no se permiten operaciones
         * modificadoras que dependan de esta validación.
         */

        Logger::error(
            'Mecanismo CSRF pendiente de definición'
        );

        Response::error(
            'No se puede verificar la protección CSRF',
            403
        );
        exit;
    }

    private static function decodificarJson(
        string $valor
    ): ?array {
        $decodificado = self::decodificarBase64Url($valor);

        if ($decodificado === null) {
            return null;
        }

        $datos = json_decode($decodificado, true);

        return is_array($datos) ? $datos : null;
    }

    private static function decodificarBase64Url(
        string $valor
    ): ?string {
        $base64 = strtr($valor, '-_', '+/');
        $base64 .= str_repeat(
            '=',
            (4 - strlen($base64) % 4) % 4
        );

        $resultado = base64_decode($base64, true);

        return $resultado === false ? null : $resultado;
    }
}
