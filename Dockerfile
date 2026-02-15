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
FROM ubuntu:noble AS base

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    NGINX_REALIP="" \
    WWW_HOME="/var/www" \
    GID=0 \
    UID=0

RUN apt-get update && \
    apt-get install -y --no-install-recommends apt-utils apt-transport-https ca-certificates gnupg wget curl jq python3 && \
    REPO_CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME") && \
    printf "Current repo version is ${REPO_CODENAME}" && \
    install -m 0755 -d /etc/apt/keyrings /etc/apt/sources.list.d && \
    curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/keyrings/nginx.gpg && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x4f4ea0aae5267a6c" | gpg --dearmor -o /etc/apt/keyrings/ondrej.gpg && \
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xde1997dcde742afa" | gpg --dearmor -o /etc/apt/keyrings/maxmind.gpg && \
    chmod 0644 /etc/apt/keyrings/*.gpg  && \
    echo "deb [signed-by=/etc/apt/keyrings/ondrej.gpg] https://ppa.launchpadcontent.net/ondrej/php/ubuntu ${REPO_CODENAME} main" > /etc/apt/sources.list.d/ondrej-php.list && \
    echo "deb [signed-by=/etc/apt/keyrings/ondrej.gpg] https://ppa.launchpadcontent.net/ondrej/nginx/ubuntu ${REPO_CODENAME} main" > /etc/apt/sources.list.d/ondrej-nginx.list && \
    echo "deb-src [signed-by=/etc/apt/keyrings/ondrej.gpg] https://ppa.launchpadcontent.net/ondrej/nginx/ubuntu ${REPO_CODENAME} main" > /etc/apt/sources.list.d/ondrej-nginx.list && \
    echo "deb [signed-by=/etc/apt/keyrings/maxmind.gpg] https://ppa.launchpadcontent.net/maxmind/ppa/ubuntu ${REPO_CODENAME} main" > /etc/apt/sources.list.d/maxmind.list && \
    apt-get update && \
    apt-get install -y git nano \
                       nginx cron supervisor \
                       libmaxminddb0 mmdb-bin  \
                       libnginx-mod-http-brotli-filter \
                       libnginx-mod-http-brotli-static && \
    apt-get autoremove -y --purge && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm /var/log/apt/history.log && rm /var/log/dpkg.log


#########################
###      BUILDER      ###
#########################
FROM base AS builder

WORKDIR /tmp

RUN apt-get update && \
    apt-get install dpkg-dev libmaxminddb-dev openssl -y && \
    apt-get build-dep nginx -y  && \
    apt-get source nginx && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && rm /var/log/apt/history.log && rm /var/log/dpkg.log && \
    if [ ! -d "ngx_http_geoip2_module" ]; then git clone https://github.com/leev/ngx_http_geoip2_module.git; fi && \
    echo './configure' > /tmp/nginx.sh && \
    nginx -V 2>&1 | grep 'configure arguments' | sed 's/.*configure arguments: //' | sed 's/ --add-dynamic-module.*$//' >> /tmp/nginx.sh && \
    echo '--add-dynamic-module=../ngx_http_geoip2_module' >> /tmp/nginx.sh && \
    sed -i ':a;N;$!ba;s/\n/ /g' /tmp/nginx.sh && \
    chmod +x /tmp/nginx.sh && \
    cd nginx-* && /tmp/nginx.sh && make -j1 modules && \
    cp /tmp/nginx-*/objs/ngx_http_geoip2_module.so /tmp/ngx_http_geoip2_module.so

COPY ./ssl /tmp/ssl


#########################
###     COMPOSING     ###
#########################
FROM base AS core

COPY --from=builder /tmp/ssl /etc/nginx/ssl
COPY --from=builder --chmod=644 /tmp/ngx_http_geoip2_module.so /usr/lib/nginx/modules/ngx_http_geoip2_module.so

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
        apt-get update && \
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
        rm -rf /etc/php/latest/fpm/pool.d/* && \
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
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
