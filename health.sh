#!/bin/bash

[[ -n "${PHP_VERSION}" ]] && status_page="fpm_ping" || status_page="nginx_status"
status_code=$(curl --write-out %{http_code} --silent --output /dev/null "http://127.0.0.1:80/${status_page}")
if [ "$status_code" != "200" ]; then exit 1; fi

exit 0;
