[EN](README.md) | RU

---

[![GitHub](/.info/github.png)](https://github.com/confido-dev/docker-nginx-pack) 
[![DockerHub](/.info/docker.png)](https://hub.docker.com/r/confido/nginx-pack) 

---

### Описание
Докер-контейнер, содержащий в себе подготовленное окружение для Web-приложений на основе Nginx и PHP-FPM с интегрированными функциями Cron и мониторинга через Nginx Amplify. Существует минималистичная вариация `core` без PHP-FPM для работы в роли Reverse Proxy или раздачи статического контента.

Есть несколько доступных веток, отличающихся наличием/отсутствием php-fpm и его версией:
````
core
php5.6
php7.0
php7.1
php7.2
php7.3
php7.4
php8.0
php8.1
php8.2
php8.3
php8.4
````
Существует так же опция с уже установленными nodejs/npm - достигается добавлением постфикса `-npm` к выбранной версии.

В случае использование внешней папки с файлами проекта, они должны быть примонтированы в контейнер по пути `/var/www`.


### Опции контейнера
Для любых из веток имеется возможность тонкой настройки и включения доп.опций, управляемых через ENV-переменные или монтирование внешних файлов

##### Amplify
````
AMPLIFY_HOST=""
AMPLIFY_UUID=""
AMPLIFY_NAME=""
AMPLIFY_KEY=""
AMPLIFY_TAG=""
AMPLIFY_HINT=""
````
Указание параметров для запуска в контейнере Amplify-агента. 

Параметр **AMPLIFY_TAG** используется для назначения тега или тегов (через запятую) данному хосту, не является обязательным параметром.

Параметр **AMPLIFY_HINT** используется для именования конфиг-файлов в самом контейнере, что помогает найти конкретный контейнер в списке элементов системы в интерфейсе Amplify, отличив его от других.

Параметр **AMPLIFY_UUID** не являются обязательными, при его отсутствии Amplify-агент сгенерирует его самостоятельно.

##### GeoIP-базы от Maxmind 
Контейнер поставляется со скомпилированным модулем NGINX для поддержки `GeoIP2` баз от MaxMind, модуль включается автоматически при нахождении внутри контейнера одного или нескольких файлов по необходимому пути:
````
/etc/nginx/data/geoip2_city.mmdb
/etc/nginx/data/geoip2_isp.mmdb
````

Базы GeoIP2 от MaxMind дают доступ к дополнительным заголовкам:
````
HTTP_GEOIP_LONGITUDE
HTTP_GEOIP_LATITUDE
HTTP_GEOIP_RADIUS
HTTP_GEOIP_TIMEZONE
HTTP_GEOIP_CITY_NAME
HTTP_GEOIP_REGION_NAME
HTTP_GEOIP_REGION_CODE
HTTP_GEOIP_COUNTRY_NAME
HTTP_GEOIP_COUNTRY_CODE
HTTP_GEOIP_CONTINENT_NAME
HTTP_GEOIP_CONTINENT_CODE
````
и
````
HTTP_GEOIP_ISP
HTTP_GEOIP_ORGANIZATION
HTTP_GEOIP_AUTONOMOUS_SYSTEM_NUMBER
HTTP_GEOIP_AUTONOMOUS_SYSTEM_ORGANIZATION
````

##### Настройка пользователя
Возможна настройка пользователя, из под которого будут выполняться процессы контейнера - что частично упрощает работу с внешними volume, подключенными к нему.
````
GID=33
UID=33
````
Параметры **UID** и **GID** указывают ID пользователя и группы, из под которого будут запущены процессы nginx и php-fpm.

##### Исправление прав на папки и файлы
При передаче **FORCE_CHMOD** или **FORCE_CHMOD_ALL**, при запуске на примонтированные в **/var/www** файлы будет оказано воздействие с исправление прав для выбранного ранее в **UID** и **GID** пользователя на корневую папку или на все файлы соответственно.

##### Включение XDebug
Для активации модуля xdebug к php необходимо передать конфигурационную строчку в переменные окружения, пример:
````
XDEBUG_CONFIG=remote_host=172.17.0.1 remote_enable=1
````

##### Real-IP модуль
При указании списка доверенных вышестоящих прокси в **NGINX_REALIP**, будет задействован nginx-модуль Real-IP для проксирования адреса посетителя, например:
````
NGINX_REALIP=172.16.0.0/12
````


### Тонкая настройка
Тонкая настройка достигается монтированием своих файлов на указанные пути внутри контейнера.

##### Настройка хостов Nginx
Для установка своих конфигураций хостов в Nginx, необходимо примонтировать их в папку по пути `/etc/nginx/sites-available/`, подключение внешних ssl-сертификатов запроектировано на точку `/etc/nginx/ssl/certs`

##### Правки к NGINX.CONF
Для добавления своих директив - монтируем файл с дополнениями в точку `/etc/nginx/conf.d/custom.conf`

##### Правки к PHP.INI
Для указания своих настроек к `php.ini`, монтируется файл с правками по пути `/etc/php/current/fpm/conf.d/99-app.ini`

##### Настройка пула PHP-FPM
Возможно применение дополнительных параметров к пулу PHP-FPM, используемого для веб-приложения. Конфиг, примонтированный по пути `/etc/php/current/fpm/pool.conf` будет применён к настройкам пула и может использоваться для настройки воркеров
или других опций.
 
##### Свой Entrypoint
При необходимости возможно указать дополнительные команды, выполняемые при старте контейнера, в отдельном Entrypoint. Точка монтирования для bash-скрипта - `/entrypoint.sh`

##### Задания Cron
Для установки в контейнере заданий в crontab, используется отдельный файл с синтаксисом, аналогичным `crontab -e`, точка монтирования - `/crontab.txt`. Файл должен оканчиваться пустой строкой и используется для прямой загрузки в Crontab.


### Пример простого использования контейнера в рамках файла `docker-compose.yml`:
````
services:
  proxy:
    image:
      confido/nginx-pack:core
    container_name:
      core-proxy
    volumes:
      - ./files:/var/www
    ports:
      - "80:80"
````