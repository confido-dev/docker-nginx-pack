#
#    $$\   $$\  $$$$$$\  $$$$$$\ $$\   $$\ $$\   $$\       $$$$$$$\   $$$$$$\   $$$$$$\  $$\   $$\
#    $$$\  $$ |$$  __$$\ \_$$  _|$$$\  $$ |$$ |  $$ |      $$  __$$\ $$  __$$\ $$  __$$\ $$ | $$  |
#    $$$$\ $$ |$$ /  \__|  $$ |  $$$$\ $$ |\$$\ $$  |      $$ |  $$ |$$ /  $$ |$$ /  \__|$$ |$$  /
#    $$ $$\$$ |$$ |$$$$\   $$ |  $$ $$\$$ | \$$$$  /       $$$$$$$  |$$$$$$$$ |$$ |      $$$$$  /
#    $$ \$$$$ |$$ |\_$$ |  $$ |  $$ \$$$$ | $$  $$<        $$  ____/ $$  __$$ |$$ |      $$  $$<
#    $$ |\$$$ |$$ |  $$ |  $$ |  $$ |\$$$ |$$  /\$$\       $$ |      $$ |  $$ |$$ |  $$\ $$ |\$$\
#    $$ | \$$ |\$$$$$$  |$$$$$$\ $$ | \$$ |$$ /  $$ |      $$ |      $$ |  $$ |\$$$$$$  |$$ | \$$\
#    \__|  \__| \______/ \______|\__|  \__|\__|  \__|      \__|      \__|  \__| \______/ \__|  \__|
#


#########################
###     BASE NGINX    ###
#########################
FROM ubuntu:resolute AS base

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    NGINX_REALIP="" \
    WWW_HOME="/var/www" \
    GID=0 \
    UID=0

RUN apt-get update --error-on=any && \
    apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/* && rm /var/log/apt/history.log && rm /var/log/dpkg.log

COPY --chmod=0644 apt/*.sources /etc/apt/sources.list.d/
COPY --chmod=0644 apt/keyrings/*.gpg /usr/share/keyrings/

RUN apt-get update --error-on=any && \
    apt-get install -y git nano curl jq \
                       nginx cron supervisor \
                       libmaxminddb0 mmdb-bin  \
                       libnginx-mod-http-geoip2 \
                       libnginx-mod-http-brotli-filter \
                       libnginx-mod-http-brotli-static && \
    apt-get autoremove -y --purge && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm /var/log/apt/history.log && rm /var/log/dpkg.log


#########################
###     COMPOSING     ###
#########################
FROM base AS core

COPY ./ssl /tmp/ssl

RUN rm -rf /etc/nginx/modules-enabled/* && \
    mkdir /usr/share/nginx/modules-available -p && \
    echo "load_module modules/ngx_http_geoip2_module.so;" > /usr/share/nginx/modules-available/mod-http-geoip2.conf && \
    ln -sf /usr/share/nginx/modules-available/mod-http-brotli-filter.conf /etc/nginx/modules-enabled/60-mod-http-brotli-filter.conf && \
    ln -sf /usr/share/nginx/modules-available/mod-http-brotli-static.conf /etc/nginx/modules-enabled/61-mod-http-brotli-static.conf && \
    rm -rf /etc/nginx/sites-enabled/* && \
    rm -f /etc/nginx/fastcgi_params && \
    mv /etc/nginx/fastcgi.conf /etc/nginx/fastcgi.default.conf && \
    rm -f /etc/nginx/nginx.conf

COPY ./nginx /etc/nginx
COPY ./supervisor /etc/supervisor

RUN find /etc/nginx/ /etc/supervisor/ -type d -print0 | xargs -0 chmod 755 && \
    find /etc/nginx/ /etc/supervisor/ -type f -print0 | xargs -0 chmod 644 && \
    unlink /var/log/nginx/access.log && \
    unlink /var/log/nginx/error.log && \
    mkdir $WWW_HOME -p


#########################
###       PHPING      ###
#########################
FROM core AS php

ARG PHP_VERSION="false"
ENV PHP_VERSION=${PHP_VERSION}

RUN if [ "${PHP_VERSION}" != "false" ]; then \
        apt-get update --error-on=any && \
        apt-get install -y libfcgi0ldbl \
                           php${PHP_VERSION}-common \
                           php${PHP_VERSION}-fpm \
                           php${PHP_VERSION}-cli \
                           php${PHP_VERSION}-xml \
                           php${PHP_VERSION}-curl \
                           php${PHP_VERSION}-sockets \
                           php${PHP_VERSION}-mysqli \
                           php${PHP_VERSION}-sqlite \
                           php${PHP_VERSION}-pgsql \
                           php${PHP_VERSION}-mongodb \
                           php${PHP_VERSION}-mbstring \
                           php${PHP_VERSION}-mcrypt \
                           php${PHP_VERSION}-bcmath \
                           php${PHP_VERSION}-intl \
                           php${PHP_VERSION}-zip \
                           php${PHP_VERSION}-gd \
                           php${PHP_VERSION}-imagick \
                           php${PHP_VERSION}-redis \
                           php${PHP_VERSION}-apcu \
                           php${PHP_VERSION}-memcached \
                           php${PHP_VERSION}-xdebug \
                           zip unzip && \
        if dpkg --compare-versions "$PHP_VERSION" lt "8.0"; then apt-get install -y php${PHP_VERSION}-json; fi && \
        if dpkg --compare-versions "$PHP_VERSION" lt "8.5"; then apt-get install -y php${PHP_VERSION}-opcache; fi && \
        apt-get clean && rm -rf /var/lib/apt/lists/* && rm /var/log/apt/history.log && rm /var/log/dpkg.log && \
        mv /etc/php/${PHP_VERSION} /etc/php/current && ln -s /etc/php/current /etc/php/${PHP_VERSION} && \
        rm -rf /etc/php/current/cli/conf.d && ln -s /etc/php/current/fpm/conf.d /etc/php/current/cli/conf.d && \
        rm -f /etc/php/current/cli/php.ini && ln -s /etc/php/current/fpm/php.ini /etc/php/current/cli/php.ini && \
        ln -s /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm && \
        rm -rf /etc/php/current/fpm/pool.d/* && \
        curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php && \
        echo "$(curl -fsSL https://composer.github.io/installer.sig)  /tmp/composer-setup.php" | sha384sum -c - && \
        php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
        rm -f /tmp/composer-setup.php \
    ; fi

COPY ./php-fpm/fpm /etc/php/current/fpm
COPY ./php-fpm/php.ini /etc/php/current/fpm/conf.d/99-app.ini

RUN if [ "${PHP_VERSION}" != "false" ]; then \
        find /etc/php/ -type d -print0 | xargs -0 chmod 755 && \
        find /etc/php/ -type f -print0 | xargs -0 chmod 644 \
    ; else \
        rm -rf /etc/php \
    ; fi


#########################
###    HAPPY ENDING   ###
#########################
FROM php AS final

COPY --chmod=755 ./health.sh /health.sh
COPY --chmod=755 ./corepoint.sh /corepoint.sh

RUN mkfifo --mode 0666 /tmp/docker.log

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/bin/bash", "/corepoint.sh"]

WORKDIR ${WWW_HOME}

HEALTHCHECK --timeout=10s CMD /bin/bash /health.sh
