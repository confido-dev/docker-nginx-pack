#!/bin/bash

[ "${PHP_VERSION}" != "false" ] && status_page="fpm_ping" || status_page="nginx_status"

status_code=$(curl --connect-timeout 2 --max-time 5 --silent --show-error \
                   --output /dev/null --write-out '%{http_code}' \
                   "http://127.0.0.1:80/$status_page") || exit 1

[ "$status_code" = "200" ]
