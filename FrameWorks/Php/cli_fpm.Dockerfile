# Dockerfile
FROM php:8.2-cli-alpine

# Install common extensions
RUN apk add --no-cache \
        php8-ctype \
        php8-curl \
        php8-mbstring \
        php8-pdo \
        php8-pdo_pgsql \
        php8-opcache \
        php8-xml \
    && curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

CMD ["php", "-a"]
