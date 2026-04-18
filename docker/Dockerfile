# ==============================================================================
# Stage 1: Composer dependencies
# ==============================================================================
FROM composer:2 AS composer-deps

WORKDIR /build
COPY app/composer.json app/composer.lock ./
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

COPY app/ .
RUN composer dump-autoload --optimize --no-dev

# ==============================================================================
# Target: app (PHP-FPM)
# Serves Laravel via PHP-FPM on port 9000
# ==============================================================================
FROM php:8.4-fpm-alpine AS app

RUN apk add --no-cache \
    libzip-dev \
    && docker-php-ext-install zip opcache

# PHP production config
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

WORKDIR /var/www/html

COPY --from=composer-deps /build /var/www/html

RUN chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

USER www-data

EXPOSE 9000

# ==============================================================================
# Target: web (Nginx)
# Reverse proxy to PHP-FPM, serves static assets
# ==============================================================================
FROM nginx:1.25-alpine AS web

COPY docker/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=composer-deps /build/public /var/www/html/public

EXPOSE 80
