
FROM php:8.3-cli-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 app

WORKDIR /app

COPY --chown=app:app comun/ /app/comun/
COPY --chown=app:app docker/nginx.conf /etc/nginx/nginx.conf
COPY --chown=app:app Backend/ /app/Backend/
COPY --chown=app:app Inventario/ /app/Inventario/
COPY --chown=app:app docker/iniciar.sh /app/iniciar.sh
COPY --chown=app:app base/ /app/base/


RUN mkdir -p /tmp/nginx/client_temp \
    /tmp/nginx/proxy_temp \
    /tmp/nginx/fastcgi_temp \
    /tmp/nginx/uwsgi_temp \
    /tmp/nginx/scgi_temp \
    && chown -R app:app /tmp/nginx \
    && chmod -R 700 /tmp/nginx

RUN printf '%s\n' \
    'display_errors=Off' \
    'display_startup_errors=Off' \
    'log_errors=On' \
    'error_log=/proc/self/fd/2' \
    > /usr/local/etc/php/conf.d/99-security.ini

ENV PORT=10000

USER app

EXPOSE 10000

CMD ["sh", "/app/iniciar.sh"]
