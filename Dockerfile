# Cloudlog production image built straight from magicbug/Cloudlog source.
# Build:  docker build --build-arg CLOUDLOG_REF=master -t cloudlog .
ARG PHP_VERSION=8.2

FROM alpine/git AS source
ARG CLOUDLOG_REF=master
RUN git clone --depth 1 --branch "${CLOUDLOG_REF}" https://github.com/magicbug/Cloudlog.git /src \
 && cd /src \
 && git rev-parse --short HEAD > /src/.cloudlog_commit \
 && echo "${CLOUDLOG_REF}" > /src/.cloudlog_version \
 && rm -rf .git .github .vscode cypress cypress.config.js docs package.json package-lock.json \
           Dockerfile Dockerfile-db docker-compose.yml script.sh

FROM php:${PHP_VERSION}-apache

ARG CLOUDLOG_REF=master
LABEL org.opencontainers.image.title="Cloudlog" \
      org.opencontainers.image.description="Cloudlog amateur radio logging, built from magicbug/Cloudlog" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.version="${CLOUDLOG_REF}"

RUN apt-get update && apt-get install -y --no-install-recommends \
        libcurl4-openssl-dev libxml2-dev libzip-dev zlib1g-dev libpng-dev \
        libjpeg62-turbo-dev libfreetype6-dev libonig-dev \
        default-mysql-client rsync curl ca-certificates \
 && docker-php-ext-configure gd --with-jpeg --with-freetype \
 && docker-php-ext-install -j"$(nproc)" pdo_mysql mysqli gd mbstring zip opcache \
 && a2enmod rewrite headers \
 && rm -rf /var/lib/apt/lists/*

RUN { \
      echo "upload_max_filesize = 64M"; \
      echo "post_max_size = 70M"; \
      echo "memory_limit = 256M"; \
      echo "max_execution_time = 300"; \
      echo "max_input_time = 300"; \
    } > /usr/local/etc/php/conf.d/cloudlog.ini \
 && sed -ri 's!AllowOverride None!AllowOverride All!g' /etc/apache2/apache2.conf

COPY --from=source --chown=www-data:www-data /src/ /var/www/html/

# Keep pristine copies of everything that gets volume-mounted, so the
# entrypoint can seed empty volumes and refresh config on upgrades.
RUN mkdir -p /opt/cloudlog-defaults \
 && cd /var/www/html \
 && for d in application/config uploads backup images assets/qslcard; do \
      mkdir -p "/opt/cloudlog-defaults/$d"; \
      [ -d "$d" ] && cp -a "$d/." "/opt/cloudlog-defaults/$d/" || true; \
    done

COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh && chmod +x /usr/local/bin/docker-entrypoint.sh

WORKDIR /var/www/html
EXPOSE 80
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s CMD curl -fsS -o /dev/null http://localhost/ || exit 1

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["apache2-foreground"]
