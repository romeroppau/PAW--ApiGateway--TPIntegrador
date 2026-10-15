<?php

class Config //obtiene valores de configuración que el sistema necesita para funcionar
{
    public static function get( 
        string $nombre,//recibe el nombre de la variable que queremos consultar
        ?string $valorPorDefecto = null //permite indicar un valor alternativo si la variable no existe
    ): ?string {
        $valor = getenv($nombre); //busca el valor en las variables de entorno

        if ($valor === false) {
            return $valorPorDefecto;
        }

        return $valor;//devuelve el valor encontrado
    }
}