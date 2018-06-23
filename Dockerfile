FROM yourdockername/base-php-nginx:latest

# add bitbucket and github to known hosts for ssh needs
WORKDIR /root/.ssh
RUN chmod 0600 /root/.ssh \
    && ssh-keyscan -t rsa bitbucket.org >> known_hosts \
    && ssh-keyscan -t rsa github.com >> known_hosts

##
## Compose Package Manager
##

# install composer dependencies
WORKDIR /var/www/app
COPY ./composer.json ./composer.lock* ./
ENV COMPOSER_VENDOR_DIR=/var/www/vendor
# RUN composer config github-oauth.github.com YOUROAUTHKEYHERE
RUN composer install --no-scripts --no-autoloader --ansi --no-interaction

##
## Node Build Tools
##

# we hardcode to develop so all tools are there for npm build
ENV NODE_ENV=develop
# install dependencies first, in a different location for easier app bind mounting for local development
WORKDIR /var/www
COPY ./package.json .
RUN npm install
# no need to cache clean in non-final build steps
ENV PATH /var/www/node_modules/.bin:$PATH
ENV NODE_PATH=/var/www/node_modules
WORKDIR /var/www/app

##
## We Are Go for Bower
##

# If you were to use Bower, this might be how to do it
# COPY ./bower.json .
# RUN bower install --allow-root

# add custom php-fpm pool settings, these get written at entrypoint startup
ENV FPM_PM_MAX_CHILDREN=20 \
    FPM_PM_START_SERVERS=2 \
    FPM_PM_MIN_SPARE_SERVERS=1 \
    FPM_PM_MAX_SPARE_SERVERS=3

# Laravel App Config
# setup app config environment at runtime
# gets put into ./.env at startup
ENV APP_NAME=Laravel \
    APP_ENV=local \
    APP_DEBUG=true \
    APP_KEY=KEYGOESHERE \
    APP_LOG=errorlog \
    APP_URL=http://localhost \
    DB_CONNECTION=mysql \
    DB_HOST=mysql \
    DB_PORT=3306 \
    DB_DATABASE=homestead \
    DB_USERNAME=homestead \
    DB_PASSWORD=secret
# Many more ENV may be needed here, and updated in docker-php-entrypoint file


# update the entrypoint to write config files and do last minute builds on startup
# notice we have a -dev version, which does different things on local docker-compose
# but we'll default to entrypoint of running the non -dev one
COPY docker-php-* /usr/local/bin/
RUN dos2unix /usr/local/bin/docker-php-entrypoint
RUN dos2unix /usr/local/bin/docker-php-entrypoint-dev


# copy in nginx config
COPY ./nginx.conf /etc/nginx/nginx.conf
COPY ./nginx-site.conf /etc/nginx/conf.d/default.conf


# copy in app code as late as possible, as it changes the most
WORKDIR /var/www/app
COPY --chown=www-data:www-data . .
RUN composer dump-autoload -o

# be sure nginx is properly passing to php-fpm and fpm is responding
HEALTHCHECK --interval=5s --timeout=3s \
  CMD curl -f http://localhost/ping || exit 1

WORKDIR /var/www/app/public
EXPOSE 80 443 9000 9001

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
