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
FROM ubuntu:hirsute as base

ENV DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1 \
    AMPLIFY_TAG="default" \
    AMPLIFY_HOST="" \
    AMPLIFY_UUID="" \
    AMPLIFY_NAME="" \
    AMPLIFY_KEY="" \
    NGINX_GEOIP=false \
    WWW_HOME="/www" \
    GID=0 \
    UID=0 \
    GIDS=""

RUN apt-get update && \
    apt-get install -y gnupg curl && \
    echo 'deb http://archive.ubuntu.com/ubuntu/ hirsute main restricted universe multiverse' > /etc/apt/sources.list && \
    echo 'deb http://archive.ubuntu.com/ubuntu/ hirsute-updates main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://archive.ubuntu.com/ubuntu/ hirsute-backports main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb http://security.ubuntu.com/ubuntu hirsute-security main restricted universe multiverse' >> /etc/apt/sources.list && \
    echo 'deb https://packages.amplify.nginx.com/debian/ stretch amplify-agent' >> /etc/apt/sources.list && \
    echo 'deb http://ppa.launchpad.net/ondrej/nginx-mainline/ubuntu hirsute main' >> /etc/apt/sources.list && \
    echo 'deb-src http://ppa.launchpad.net/ondrej/nginx-mainline/ubuntu hirsute main' >> /etc/apt/sources.list && \
    echo 'deb http://ppa.launchpad.net/maxmind/ppa/ubuntu hirsute main' >> /etc/apt/sources.list && \
    echo 'deb http://ppa.launchpad.net/ondrej/php/ubuntu hirsute main' >> /etc/apt/sources.list && \
    curl -fs https://nginx.org/keys/nginx_signing.key | apt-key add - > /dev/null 2>&1 && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4F4EA0AAE5267A6C && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys DE1997DCDE742AFA && \
    apt-get update && \
    apt-get upgrade -y && \
    apt-get dist-upgrade -y && \
    apt-get install -y cron supervisor \
                       nginx nginx-amplify-agent \
                       libmaxminddb0 libmaxminddb-dev mmdb-bin && \
    apt-get purge -y gnupg  && \
    apt-get autoremove --purge -y && \
    apt-get clean && rm -rf /var/lib/apt/lists/*


#########################
###      BUILDER      ###
#########################
FROM base as builder

ARG NOT_DUMMY_SSL
ENV NOT_DUMMY_SSL ${NOT_DUMMY_SSL}

WORKDIR /tmp

RUN apt-get update && \
    apt-get install git dpkg-dev openssl -y && \
    apt-get build-dep nginx -y  && \
    apt-get source nginx && \
    if [ ! -d "ngx_http_geoip2_module" ]; then git clone https://github.com/leev/ngx_http_geoip2_module.git; fi

RUN echo './configure' > /tmp/nginx.sh && \
    nginx -V 2>&1 | grep 'configure arguments' | sed 's/.*configure arguments: //' | sed 's/ --add-dynamic-module.*$//' >> /tmp/nginx.sh && \
    echo '--add-dynamic-module=../ngx_http_geoip2_module' >> /tmp/nginx.sh && \
    sed -i ':a;N;$!ba;s/\n/ /g' /tmp/nginx.sh && \
    chmod +x /tmp/nginx.sh && \
    cd nginx-* && /tmp/nginx.sh && make modules && \
    cp /tmp/nginx-*/objs/ngx_http_geoip2_module.so /tmp/ngx_http_geoip2_module.so

COPY ./ssl /tmp/ssl

RUN if [ "${NOT_DUMMY_SSL}" = true ]; then \
        rm /tmp/ssl/* && \
        openssl dhparam -out /tmp/ssl/dhparam.pem 4096 && \
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
                    -keyout /tmp/ssl/default.key -out /tmp/ssl/default.crt \
                    -subj '/C=NO/ST=Null/L=Null/O=Null/OU=Null/CN=Null' \
    ; fi


#########################
###     COMPOSING     ###
#########################
FROM base as core

COPY --from=builder /tmp/ssl /etc/nginx/ssl
COPY --from=builder /tmp/ngx_http_geoip2_module.so /usr/lib/nginx/modules/

RUN rm -rf /etc/nginx/modules-enabled/* && \
        chmod 644 /usr/lib/nginx/modules/ngx_http_geoip2_module.so && \
    echo "load_module modules/ngx_http_geoip2_module.so;" > /usr/share/nginx/modules-available/mod-http-geoip2.conf && \
    rm -rf /etc/nginx/sites-enabled/* && \
    rm -f /etc/nginx/fastcgi_params && \
    mv /etc/nginx/fastcgi.conf /etc/nginx/fastcgi.default.conf && \
    rm -f /etc/nginx/nginx.conf

COPY ./nginx /etc/nginx
COPY ./amplify /etc/amplify-agent

RUN unlink /var/log/nginx/error.log && \
    unlink /var/log/nginx/access.log && \
    mkdir $WWW_HOME -p


#########################
###       PHPING      ###
#########################
FROM core as php

ARG PHP_VERSION
ENV PHP_VERSION ${PHP_VERSION}


RUN if [ -n "${PHP_VERSION}" ]; then \
        apt-get update && \
        apt-get install -y libfcgi0ldbl \
                           php${PHP_VERSION}-common \
                           php${PHP_VERSION}-fpm \
                           php${PHP_VERSION}-cli \
                           php${PHP_VERSION}-xml \
                           php${PHP_VERSION}-curl \
                           php${PHP_VERSION}-mysqli \
                           php${PHP_VERSION}-mbstring \
                           php${PHP_VERSION}-bcmath \
                           php${PHP_VERSION}-opcache \
                           php${PHP_VERSION}-zip \
                           php${PHP_VERSION}-gd \
                           php${PHP_VERSION}-imagick \
                           php${PHP_VERSION}-xdebug \
                           unzip && \
        if [ "${PHP_VERSION}" != "8.0" ] && [ "${PHP_VERSION}" != "8.1" ]; then \
            apt-get install -y php${PHP_VERSION}-json \
        ; fi && \
        apt-get clean && \
        rm -rf /var/lib/apt/lists/* \
    ; fi

RUN if [ -n "${PHP_VERSION}" ]; then \
        mv /etc/php/${PHP_VERSION} /etc/php/current && ln -s /etc/php/current /etc/php/${PHP_VERSION} && \
        rm -rf /etc/php/current/cli/conf.d && ln -s /etc/php/current/fpm/conf.d /etc/php/current/cli/conf.d && \
        rm -f /etc/php/current/cli/php.ini && ln -s /etc/php/current/fpm/php.ini /etc/php/current/cli/php.ini && \
        ln -s /usr/sbin/php-fpm${PHP_VERSION} /usr/sbin/php-fpm && \
        rm -rf /etc/php/latest/fpm/pool.d/* \
    ; fi

RUN if [ -n "${PHP_VERSION}" ]; then \
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer \
    ; fi

COPY ./php-fpm/fpm /etc/php/current/fpm
COPY ./php-fpm/php.ini /etc/php/current/fpm/conf.d/99-app.ini

RUN if [ -z "$(ls -A "$WWW_HOME")" ]; then \
        if [ -n "${PHP_VERSION}" ]; then \
            echo '<?php phpinfo(); ?>' > $WWW_HOME/index.php \
        ; else \
            echo 'Hello World!' > $WWW_HOME/index.html \
        ; fi \
    ; fi

RUN if [ -z "${PHP_VERSION}" ]; then \
        rm -rf /etc/supervisor && \
        rm -rf /etc/php \
    ; fi


#########################
###    HAPPY ENDING   ###
#########################
FROM php as final

COPY ./health.sh /health.sh
COPY ./corepoint.sh /corepoint.sh
COPY ./supervisor /etc/supervisor

RUN mkfifo --mode 0666 /tmp/docker.log

EXPOSE 80
EXPOSE 443

ENTRYPOINT ["/bin/bash", "/corepoint.sh"]

HEALTHCHECK --timeout=10s CMD /bin/bash /health.sh
