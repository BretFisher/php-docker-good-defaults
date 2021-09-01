# php:7.4.23-fpm-buster breaks readline which is one of the extensions
# installed in this image. Keep an eye on issue number 1197 on github
# https://github.com/docker-library/php/issues/1197
FROM php:7.4.22-fpm-buster

ENV NGINX_VERSION=1.20.1 \
    PKG_RELEASE=1~buster \
    NJS_VERSION=0.5.3 \
    NODE_VERSION=14.17.6

# this is a sample BASE image, that php_fpm projects can start FROM
# it's got a lot in it, but it's designed to meet dev and prod needs in single image
# I've tried other things like splitting out php_fpm and nginx containers
# or multi-stage builds to keep it lean, but this is my current design for
## single image that does nginx and php_fpm
## usable with bind-mount and unique dev-only entrypoint file that builds
## some things on startup when developing locally
## stores all code in image with proper default builds for production

# install apt dependencies
# some of these are not needed in all php projects
# NOTE: you should prob use specific versions of some of these so you don't break your app
RUN apt-get update && apt-get install --no-install-recommends --no-install-suggests -y \
    apt-transport-https \
    ca-certificates \
    openssh-client \
    curl \ 
    dos2unix \
    git \
    gnupg2 \
    dirmngr \
    g++ \	
    jq \
    libedit-dev \
    libfcgi0ldbl \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libmcrypt-dev \
    libpq-dev \
    # libssl-dev \
    # openssh-client \
    supervisor \
    unzip \
    zip \
    && rm -r /var/lib/apt/lists/*


# Install extensions using the helper script provided by the base image
RUN docker-php-ext-install \
    pdo_mysql \
    mysqli \
    json \
    readline \
    gd \
    intl

# configure gd
RUN docker-php-ext-configure gd \
    --with-freetype=/usr/include/freetype2 \
    --with-jpeg=/usr/include/

# configure intl
RUN docker-php-ext-configure intl


# install nginx (copied from official nginx Dockerfile)
RUN NGINX_GPGKEY=573BFD6B3D8FBC641079A6ABABF5BD827BD9BF62; \
	found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $NGINX_GPGKEY from $server"; \
		apt-key adv --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$NGINX_GPGKEY" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $NGINX_GPGKEY" && exit 1; \
	echo "deb http://nginx.org/packages/debian/ buster nginx" >> /etc/apt/sources.list.d/nginx.list \
	&& apt-get update \
	&& apt-get install --no-install-recommends --no-install-suggests -y \
            nginx=${NGINX_VERSION}-${PKG_RELEASE} \
            nginx-module-xslt=${NGINX_VERSION}-${PKG_RELEASE} \
            nginx-module-geoip=${NGINX_VERSION}-${PKG_RELEASE} \
            nginx-module-image-filter=${NGINX_VERSION}-${PKG_RELEASE} \
            nginx-module-njs=${NGINX_VERSION}+${NJS_VERSION}-${PKG_RELEASE} \
						gettext-base \
	&& rm -rf /var/lib/apt/lists/*

# forward nginx request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log

# install composer so we can run dump-autoload at entrypoint startup in dev
# copied from official composer Dockerfile
ENV PATH="/composer/vendor/bin:$PATH" \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_VENDOR_DIR=/var/www/vendor \
    COMPOSER_HOME=/composer

COPY ./install-composer.sh /tmp//install-composer.sh

RUN /tmp/install-composer.sh && rm -f /tmp//install-composer.sh \
 && composer --ansi --version --no-interaction

# install node for running gulp at container entrypoint startup in dev
# copied from official node Dockerfile
# gpg keys listed at https://github.com/nodejs/node#release-team
RUN set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    94AE36675C464D64BAFA68DD7434390BDBE9B9C5 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    71DCFD284A79C3B38668286BC97EC7A07EDE3FC1 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    DD8F2338BAE7501E3DD5AC78C273792F7D83545D \
    A48C2BEE680E841632CD4E44F07496B3EB3C1762 \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    B9E2F5981AA6E0CD28160D9FF13993A75599653C \
  ; do \
    gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
    gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
  done

ENV NPM_CONFIG_LOGLEVEL info

RUN curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && grep " node-v$NODE_VERSION-linux-x64.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && tar -xJf "node-v$NODE_VERSION-linux-x64.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-x64.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && ln -s /usr/local/bin/node /usr/local/bin/nodejs

ENV PATH /var/www/node_modules/.bin:$PATH

COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
