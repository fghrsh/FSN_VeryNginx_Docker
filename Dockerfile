FROM alpine:3.10

LABEL maintainer="FGHRSH <fghrsh@wxw.moe>"

ENV NGINX_VERSION 1.17.3
ENV OPENSSL_VERSION 1.1.1d
ENV LuaJIT_VERSION 2.1.0-beta3
ENV ngx_devel_kit_VERSION 0.3.1
ENV lua_nginx_module_VERSION 0.10.15
ENV LUAJIT_LIB /usr/local/lib
ENV LUAJIT_INC /usr/local/include/luajit-2.1/

RUN GPG_KEYS=B0F4253373F8F6F510D42178520A9993A1C052F8 \
	&& CONFIG="\
		--prefix=/etc/nginx \
		--sbin-path=/usr/sbin/nginx \
		--modules-path=/usr/lib/nginx/modules \
		--conf-path=/etc/nginx/nginx.conf \
		--error-log-path=/var/log/nginx/error.log \
		--http-log-path=/var/log/nginx/access.log \
		--pid-path=/var/run/nginx.pid \
		--lock-path=/var/run/nginx.lock \
		--http-client-body-temp-path=/var/cache/nginx/client_temp \
		--http-proxy-temp-path=/var/cache/nginx/proxy_temp \
		--http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
		--http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
		--http-scgi-temp-path=/var/cache/nginx/scgi_temp \
		--user=nginx \
		--group=nginx \
		--with-http_ssl_module \
		--with-http_realip_module \
		--with-http_addition_module \
		--with-http_sub_module \
		--with-http_dav_module \
		--with-http_flv_module \
		--with-http_mp4_module \
		--with-http_gunzip_module \
		--with-http_gzip_static_module \
		--with-http_random_index_module \
		--with-http_secure_link_module \
		--with-http_stub_status_module \
		--with-http_auth_request_module \
		--with-http_xslt_module=dynamic \
		--with-http_image_filter_module=dynamic \
		--with-http_geoip_module=dynamic \
		--with-threads \
		--with-stream \
		--with-stream_ssl_module \
		--with-stream_ssl_preread_module \
		--with-stream_realip_module \
		--with-stream_geoip_module=dynamic \
		--with-http_slice_module \
		--with-mail \
		--with-mail_ssl_module \
		--with-compat \
		--with-file-aio \
		--with-http_v2_module \
		--with-zlib=./zlib-cf \
		--with-openssl=./openssl \
		--with-openssl-opt='zlib' \
		--with-ld-opt=-Wl,-rpath,/usr/local/lib/ \
		--add-module=./ngx_devel_kit-$ngx_devel_kit_VERSION \
		--add-module=./lua-nginx-module-$lua_nginx_module_VERSION \
		--add-module=./ngx_brotli \
		--add-module=./headers-more-nginx-module \
	" \
	&& addgroup -g 82 -S nginx \
	&& adduser -D -S -h /var/cache/nginx -s /sbin/nologin -u 82 -G nginx nginx \
	&& apk add --no-cache --virtual .build-deps \
		gcc \
		libc-dev \
		make \
		openssl-dev \
		pcre-dev \
		zlib-dev \
		linux-headers \
		curl \
		gnupg1 \
		libxslt-dev \
		gd-dev \
		geoip-dev \
		git \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz -o nginx.tar.gz \
	&& curl -fSL https://nginx.org/download/nginx-$NGINX_VERSION.tar.gz.asc  -o nginx.tar.gz.asc \
	&& export GNUPGHOME="$(mktemp -d)" \
	&& found=''; \
	for server in \
		ha.pool.sks-keyservers.net \
		hkp://keyserver.ubuntu.com:80 \
		hkp://p80.pool.sks-keyservers.net:80 \
		pgp.mit.edu \
	; do \
		echo "Fetching GPG key $GPG_KEYS from $server"; \
		gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
	done; \
	test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
	gpg --batch --verify nginx.tar.gz.asc nginx.tar.gz \
	&& rm -rf "$GNUPGHOME" nginx.tar.gz.asc \
	&& mkdir -p /usr/src \
	&& tar -zxC /usr/src -f nginx.tar.gz \
	&& rm nginx.tar.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& git clone https://github.com/eustas/ngx_brotli.git \
	&& cd ngx_brotli \
	&& git submodule update --init --recursive \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& git clone https://github.com/cloudflare/zlib.git zlib-cf \
	&& cd zlib-cf \
	&& make -f Makefile.in distclean \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& curl https://www.openssl.org/source/openssl-$OPENSSL_VERSION.tar.gz -o openssl.gz \
	&& tar -xzf openssl.gz \
	&& mv openssl-$OPENSSL_VERSION openssl \
	&& rm openssl.gz \
	&& cd /usr/src/nginx-$NGINX_VERSION/openssl \
	&& curl https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/openssl-1.1.1d-chacha_draft.patch | patch -p1 \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& git clone https://github.com/openresty/headers-more-nginx-module.git \
	&& curl https://raw.githubusercontent.com/hakasenyang/openssl-patch/master/nginx_strict-sni_1.15.10.patch | patch -p1 \
	&& curl http://luajit.org/download/LuaJIT-$LuaJIT_VERSION.zip -o LuaJIT.zip \
	&& unzip LuaJIT.zip \
	&& rm LuaJIT.zip \
	&& cd LuaJIT-$LuaJIT_VERSION \
	&& make \
	&& make install \
	&& cd /usr/src/nginx-$NGINX_VERSION \
	&& wget https://github.com/simpl/ngx_devel_kit/archive/v$ngx_devel_kit_VERSION.zip \
	&& unzip v$ngx_devel_kit_VERSION.zip \
	&& rm v$ngx_devel_kit_VERSION.zip \
	&& wget https://github.com/openresty/lua-nginx-module/archive/v$lua_nginx_module_VERSION.zip \
	&& unzip v$lua_nginx_module_VERSION.zip \
	&& rm v$lua_nginx_module_VERSION.zip \
	&& ./configure $CONFIG \
	&& make -j$(getconf _NPROCESSORS_ONLN) \
	&& make install \
	&& rm -rf /etc/nginx/html/ \
	&& mkdir /etc/nginx/conf.d/ \
	&& mkdir -p /usr/share/nginx/html/ \
	&& install -m644 html/index.html /usr/share/nginx/html/ \
	&& install -m644 html/50x.html /usr/share/nginx/html/ \
	&& ln -s ../../usr/lib/nginx/modules /etc/nginx/modules \
	&& strip /usr/sbin/nginx* \
	&& strip /usr/lib/nginx/modules/*.so \
	&& cd / \
	&& rm -rf /usr/src/nginx-$NGINX_VERSION \
	\
	# xBring in gettext so we can get `envsubst`, then throw
	# the rest away. To do this, we need to install `gettext`
	# then move `envsubst` out of the way so `gettext` can
	# be deleted completely, then move `envsubst` back.
	&& apk add --no-cache --virtual .gettext gettext \
	&& mv /usr/bin/envsubst /tmp/ \
	\
	&& runDeps="$( \
		scanelf --needed --nobanner --format '%n#p' /usr/sbin/nginx /usr/lib/nginx/modules/*.so /usr/local/lib/libluajit*.so /tmp/envsubst \
			| tr ',' '\n' \
			| sort -u \
			| awk 'system("[ -e /usr/local/lib/" $1 " ]") == 0 { next } { print "so:" $1 }' \
	)" \
	&& apk add --no-cache --virtual .nginx-rundeps $runDeps \
	&& apk del .build-deps \
	&& apk del .gettext \
	&& mv /tmp/envsubst /usr/local/bin/ \
	\
	# Bring in tzdata so users could set the timezones through the environment
	# variables
	&& apk add --no-cache tzdata \
	\
	# forward request and error logs to docker log collector
	&& ln -sf /dev/stdout /var/log/nginx/access.log \
	&& ln -sf /dev/stderr /var/log/nginx/error.log \
	&& nginx -V

COPY conf/ /etc/nginx/

COPY verynginx/ /opt/verynginx/

RUN chown nginx:nginx /opt/verynginx/configs/config.json

EXPOSE 80 443

STOPSIGNAL SIGTERM

CMD ["nginx", "-g", "daemon off;"]
