# syntax=docker/dockerfile:1.6

# Alpine + PHP-CLI (no FPM)
FROM php:8.3-cli-alpine

ARG WWWGROUP=1000
ARG WWWUSER=1000

ENV APP_ENV=local \
    APP_DEBUG=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1 \
    COMPOSER_ALLOW_SUPERUSER=1

# ---- base system & build deps ----
# build-base: gcc/g++/make, needed for pecl builds
# linux-headers: some pecl builds
# runtime libs: ICU, zip, image libs, mariadb client, etc.
RUN apk add --no-cache \
      bash git curl unzip \
      icu-dev libzip-dev oniguruma-dev \
      libpng-dev libjpeg-turbo-dev freetype-dev \
      libxml2-dev openssl-dev \
      inotify-tools \
      mariadb-client \
      nodejs npm \
    && apk add --no-cache --virtual .build-deps \
      build-base autoconf linux-headers

# ---- PHP extensions (core) ----
# gd needs explicit configure flags for JPEG/Freetype on Alpine
RUN docker-php-ext-configure gd --with-freetype --with-jpeg \
 && docker-php-ext-install -j"$(nproc)" \
      bcmath exif intl pcntl calendar pdo_mysql zip gd mbstring

# ---- PECL extensions ----
RUN pecl install redis \
 && pecl install swoole \
 && docker-php-ext-enable redis swoole

# ---- composer ----
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

# ---- app user & dirs ----
RUN addgroup -g ${WWWGROUP} -S www-user \
 && adduser  -u ${WWWUSER} -S -G www-user www-user \
 && mkdir -p /var/www/html \
 && chown -R ${WWWUSER}:${WWWGROUP} /var/www

WORKDIR /var/www/html

# ---- app code ----
# (If you build in CI, prefer a .dockerignore to skip node_modules/vendor)
COPY --chown=${WWWUSER}:${WWWGROUP} . .

# If you want to install deps at build time, uncomment:
# RUN composer install --no-dev --prefer-dist --no-interaction --no-progress

# Ensure runtime perms (keep writable by app)
RUN chown -R ${WWWUSER}:${WWWGROUP} vendor bootstrap/cache storage

# You no longer need supervisord with Octane as PID 1, so skip copying its conf.
# Keep your existing start script name; we’ll run Octane there.
COPY --chown=${WWWUSER}:${WWWGROUP} start-container.sh /usr/local/bin/start-container
RUN chmod +x /usr/local/bin/start-container \
 && sed -i 's/\r$//' /usr/local/bin/start-container

EXPOSE 8000

USER ${WWWUSER}

# With CLI base, this becomes PID 1 and should exec Octane
CMD ["start-container"]
