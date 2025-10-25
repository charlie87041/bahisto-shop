# syntax=docker/dockerfile:1

FROM php:8.3-fpm-bullseye AS base

ARG WWWGROUP=1000
ARG WWWUSER=1000

ENV APP_ENV=local \
    APP_DEBUG=1 \
    PHP_OPCACHE_VALIDATE_TIMESTAMPS=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
        unzip \
        libzip-dev \
        libpng-dev \
        libonig-dev \
        libxml2-dev \
        libicu-dev \
        libjpeg-dev \
        libfreetype6-dev \
        libssl-dev \
        inotify-tools \
        mariadb-client \
        supervisor \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        intl \
        pcntl \
        calendar \
        pdo_mysql \
        zip \
        gd \
    && pecl install redis \
    && pecl install swoole \
    && docker-php-ext-enable redis swoole \
    && curl -sL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer


RUN groupadd --force -g ${WWWGROUP} www-user \
    && useradd -ms /bin/bash --no-user-group -g ${WWWGROUP} -u ${WWWUSER} www-user \
    && usermod -aG www-data www-user \
    && chown -R ${WWWUSER}:${WWWGROUP} /var/www

WORKDIR /var/www/html

COPY --chown=${WWWUSER}:${WWWGROUP} . .

RUN test -f .env || (echo ".env missing right after COPY" && ls -la && exit 1)


RUN if [ ! -d vendor ]; then \
        echo "Composer dependencies were not found in the image."; \
        echo "Make sure 'composer install' runs before building so vendor is included in the context."; \
        exit 1; \
    fi \
    && chown -R ${WWWUSER}:${WWWGROUP} vendor bootstrap/cache storage

COPY --chown=${WWWUSER}:${WWWGROUP} supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY  --chown=${WWWUSER}:${WWWGROUP} start-container.sh /usr/local/bin/start-container

RUN chmod +x /usr/local/bin/start-container \
 && sed -i 's/\r$//' /usr/local/bin/start-container

EXPOSE 8000

USER ${WWWUSER}

CMD ["start-container"]