
FROM php:8.3-cli-bookworm

RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx \
    && docker-php-ext-install pdo_mysql \
    && rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 app

WORKDIR /app

COPY --chown=app:app comun/ /app/comun/
COPY --chown=app:app docker/nginx.conf /etc/nginx/nginx.conf

RUN mkdir -p /tmp/nginx/client_temp \
    /tmp/nginx/proxy_temp \
    /tmp/nginx/fastcgi_temp \
    /tmp/nginx/uwsgi_temp \
    /tmp/nginx/scgi_temp \
    && chown -R app:app /tmp/nginx

ENV PORT=10000

USER app

EXPOSE 10000

CMD ["sh", "-c", "php -S 127.0.0.1:9000 -t /app/comun /app/comun/index.php & exec nginx -g 'daemon off;'"]
