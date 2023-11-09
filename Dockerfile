FROM alpine:3.10 AS nginx-builder

# We first build a minimal nginx version with headers-more module included (this is the only way to build an nginx module: build nginx with the module included)
# From this build, we only keep the dynamic module
# We chose to keep using official Docker image instead of the freshly built nginx to lower the risk of compatibility and/or maintainability issues

# Note that building a module that is compatible with an existing nginx executable is not trivial. For example, if we remove --with-http_ssl_module flag then nginx claims that
# the freshly built .so module is not "binary compatible" at runtime
# Reason is we are supposed to use the same configure options as what was used to generate nginx but using the --with-compat makes it less strict

ENV NGINX_VERSION nginx-1.23.3
ENV HEADERS_MORE_VERSION v0.34

RUN apk --update add openssl-dev pcre-dev zlib-dev wget build-base && \
    mkdir -p /tmp/src && \
    cd /tmp/src && \
    wget http://nginx.org/download/${NGINX_VERSION}.tar.gz && \
    tar -zxvf ${NGINX_VERSION}.tar.gz && \
    wget https://github.com/openresty/headers-more-nginx-module/archive/${HEADERS_MORE_VERSION}.tar.gz && \
    tar -xzvf ${HEADERS_MORE_VERSION}.tar.gz && \
    cd /tmp/src/${NGINX_VERSION} && \
    ./configure \
        --with-compat \
        --with-http_ssl_module \
        --with-http_gzip_static_module \
        --add-dynamic-module=../headers-more-nginx-module-0.34 \
        --prefix=/etc/nginx \
        --http-log-path=/var/log/nginx/access.log \
        --error-log-path=/var/log/nginx/error.log \
        --sbin-path=/usr/local/sbin/nginx && \
    make && \
    make install

FROM nginx:1.23.3-alpine
MAINTAINER Philippe Mioulet
COPY dhparam.pem /etc/nginx/dhparam/
COPY default.conf /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=nginx-builder /etc/nginx/modules/ngx_http_headers_more_filter_module.so /etc/nginx/modules/

RUN apk add --update openssl curl ncurses tiff && \
    mkdir /etc/nginx/conf.d/conf-enabled && \
    mkdir /etc/nginx/extra-conf && \
    mkdir /etc/nginx/conf.d/includes

COPY header.conf /etc/nginx/conf.d/includes/header.conf
RUN true
COPY default.conf /etc/nginx/conf.d/default.conf
RUN true
COPY 403.html /var/www/html/403.html
RUN true
COPY 404.html /var/www/html/404.html
RUN true
COPY 405.html /var/www/html/405.html
RUN true
COPY 500.html /var/www/html/500.html

RUN adduser -D -h /home/centos -s /bin/sh centos -u 1000

RUN mkdir -p /etc/nginx/certs && \
  chown -R centos: /etc/nginx/certs && \
  touch /var/run/nginx.pid && \
  chown -R centos: /var/run/nginx.pid && \
  chown -R centos: /var/cache/nginx && \
  chown -R centos: /etc/nginx/conf.d
RUN apk del nginx-module-xslt

USER centos

COPY entrypoint.sh /

ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 8080 8443
