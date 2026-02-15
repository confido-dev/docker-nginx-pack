#!/bin/bash

set -e

#########################
###        USER       ###
#########################
echo " :: INITING USER"
# Creating GID
echo " ---> Using GID #${GID}"
WWW_GROUP=$(awk -v val=$GID -F ":" '$3==val{print $1}' /etc/group)
if [ -z "$WWW_GROUP" ]; then
    WWW_GROUP="g${GID}"
    addgroup --gid $GID $WWW_GROUP
    echo " ---> Group ${WWW_GROUP} created"
else echo " ---> Using group ${WWW_GROUP}"; fi
# Creating UID
echo " ---> Using UID #${UID}"
WWW_USER=$(awk -v val=$UID -F ":" '$3==val{print $1}' /etc/passwd)
if [ -z "$WWW_USER" ]; then
    WWW_USER="u${UID}"
    adduser --shell /bin/bash --home /home/$WWW_USER --uid $UID --gid $GID --disabled-password --gecos "" $WWW_USER
    echo " ---> User ${WWW_USER} created"
else echo " ---> Using user ${WWW_USER}"; fi
# Chowning app files
if [ -n "${FORCE_CHMOD}" ]; then
    chown $UID:$GID $WWW_HOME
    chmod 0750 $WWW_HOME
fi
# Chowning app files recursive
if [ -n "${FORCE_CHMOD_ALL}" ]; then
    chown $UID:$GID $WWW_HOME -R
    chmod 0750 $WWW_HOME -R
fi
# Fixing NGINX
sh -c "sed -i.old -e 's~^user.*$~user $WWW_USER $WWW_GROUP;~' /etc/nginx/nginx.conf"
rm -f /etc/nginx/nginx.conf.old
# Fixing PHP-FPM
if [ "${PHP_VERSION}" != "false" ]; then
    sh -c "sed -i.old -e 's~^user =.*$~user = $WWW_USER~' /etc/php/current/fpm/pool.d/www.conf"
    sh -c "sed -i.old -e 's~^group =.*$~group = $WWW_GROUP~' /etc/php/current/fpm/pool.d/www.conf"
	rm -f /etc/php/current/fpm/pool.d/www.conf.old
fi


#########################
###     HOST CONFS    ###
#########################
echo " :: INITING HOSTS"
# Cleaning
rm /etc/nginx/sites-enabled/* -rf
cd /etc/nginx/sites-available/
# Counting
CONFS=$(ls /etc/nginx/sites-available/ -1 | wc -l)
# Enabling
for conf in *; do
    if  [ $conf != 'default' ]  || [ $CONFS == '1' ]; then
        echo " ---> Processing $conf file..."
        ln -sf /etc/nginx/sites-available/$conf /etc/nginx/sites-enabled/$conf
    fi
done


#########################
###      OPTIONS      ###
#########################
echo " :: INITING OPTIONS"
# Cleaning RealIP
: > /etc/nginx/conf.d/realip.conf
# Cleaning GeoIP
: > /etc/nginx/conf.d/geoip.conf
: > /etc/nginx/fastcgi.d/geoip.conf
rm -f /etc/nginx/modules-enabled/50-mod-http-geoip2.conf
# Resetting proxy_pass headers
cat /etc/nginx/conf.d/sources/proxy-headers-basic.conf > /etc/nginx/conf.d/proxy-headers.conf
# Cleaning XDebug
rm -f /etc/php/current/fpm/conf.d/20-xdebug.ini
# RealIP
if [ -n "${NGINX_REALIP}" ]; then
    echo " ---> Enabling NGINX RealIP module"
    for i in ${NGINX_REALIP//,/ }; do
        echo "set_real_ip_from $i;" >> /etc/nginx/conf.d/realip.conf
    done
    cat /etc/nginx/conf.d/sources/realip.conf >> /etc/nginx/conf.d/realip.conf
fi
# MaxMind GeoIP2 City
if [ -f "/etc/nginx/data/geoip2_city.mmdb" ]; then
    echo " ---> Enabling MaxMind GeoIP City module"
    cat /etc/nginx/conf.d/sources/geoip-city.conf >> /etc/nginx/conf.d/geoip.conf
    cat /etc/nginx/fastcgi.d/sources/geoip-city.conf >> /etc/nginx/fastcgi.d/geoip.conf
    cat /etc/nginx/conf.d/sources/proxy-headers-geoip-city.conf >> /etc/nginx/conf.d/proxy-headers.conf
fi
# MaxMind GeoIP2 ISP
if [ -f "/etc/nginx/data/geoip2_isp.mmdb" ]; then
    echo " ---> Enabling MaxMind GeoIP ISP module"
    cat /etc/nginx/conf.d/sources/geoip-isp.conf >> /etc/nginx/conf.d/geoip.conf
    cat /etc/nginx/fastcgi.d/sources/geoip-isp.conf >> /etc/nginx/fastcgi.d/geoip.conf
    cat /etc/nginx/conf.d/sources/proxy-headers-geoip-isp.conf >> /etc/nginx/conf.d/proxy-headers.conf
fi
# MaxMind GeoIP2
if [ -f "/etc/nginx/data/geoip2_isp.mmdb" ] || [ -f "/etc/nginx/data/geoip2_city.mmdb" ]; then
    ln -sf /usr/share/nginx/modules-available/mod-http-geoip2.conf /etc/nginx/modules-enabled/50-mod-http-geoip2.conf
fi
# XDebug
if [ "${PHP_VERSION}" != "false" ] && [ -n "${XDEBUG_CONFIG}" ]; then
    echo " ---> Enabling XDebug module"
    ln -sf /etc/php/current/mods-available/xdebug.ini /etc/php/current/fpm/conf.d/70-xdebug.ini
fi


#########################
###      TESTING      ###
#########################
echo " :: TESTING NGINX"
nginx -t
if [ "${PHP_VERSION}" != "false" ]; then
    echo " :: TESTING PHP-FPM"
    php-fpm --fpm-config /etc/php/current/fpm/php-fpm.conf --allow-to-run-as-root -t
fi


#########################
###   EXIT FUNCTION   ###
#########################
stop(){
  echo " :: EXITING"
  kill -s SIGTERM $(cat /run/supervisord.pid)
  wait $(cat /run/supervisord.pid)
  exit 0
}


#########################
###    APP INITING    ###
#########################
if [ -f "/entrypoint.sh" ]; then
    echo " :: RUNNING APP ENTRYPOINT"
    /bin/bash /entrypoint.sh
fi


#########################
###   CRONTAB START   ###
#########################
if [ -f "/crontab.txt" ]; then
    echo " :: LOADING CRONTAB"
    env | while read -r LINE; do
        IFS="=" read VAR VAL <<< ${LINE}
        sed --in-place "/^${VAR}/d" /etc/security/pam_env.conf || true
        echo "${VAR} DEFAULT=\"${VAL}\"" >> /etc/security/pam_env.conf
    done
    crontab -u $WWW_USER /crontab.txt
fi


#########################
###      STARTING     ###
#########################
echo " :: STARTING"
cat /etc/supervisor/supervisord_core.conf > /etc/supervisor/supervisord.conf
if [ -f "/crontab.txt"   ]; then cat /etc/supervisor/supervisord_cron.conf >> /etc/supervisor/supervisord.conf; fi
if [ "${PHP_VERSION}" != "false" ]; then cat /etc/supervisor/supervisord_php.conf >> /etc/supervisor/supervisord.conf; fi
unset NGINX_REALIP PHP_VERSION
unset GID UID FORCE_CHMOD FORCE_CHMOD_ALL
trap stop SIGTERM SIGINT SIGQUIT SIGHUP
/usr/bin/supervisord -c /etc/supervisor/supervisord.conf & SUPERVISOR_PID=$!
wait "${SUPERVISOR_PID}"
