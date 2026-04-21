FROM dunglas/frankenphp:php8.5.5-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    git \
    unzip \
    zip \
    && rm -rf /var/lib/apt/lists/*

RUN install-php-extensions openssl zip gd curl json pdo_mysql

WORKDIR /app

COPY . /app

COPY docker/start.sh /usr/local/bin/start-app
COPY Caddyfile /etc/caddy/Caddyfile

RUN chmod +x /usr/local/bin/start-app

EXPOSE 80

CMD ["/usr/local/bin/start-app"]
