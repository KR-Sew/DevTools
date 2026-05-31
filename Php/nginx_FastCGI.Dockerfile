# Dockerfile
FROM php:8.2-fpm-alpine

# Install extensions
RUN apk add --no-cache \
    php8-fpm \
    php8-mbstring \
    php8-curl \
    php8-xml \
    php8-pdo_pgsql \
    php8-opcache

EXPOSE 9000

CMD ["php-fpm"]
