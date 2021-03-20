#!/usr/bin/env bash
PATH=/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin:~/bin
export PATH

compile_nginx(){
  apt-get update &>/dev/null
  apt-get install -y build-essential libpcre3 libpcre3-dev zlib1g-dev git libxslt-dev libssl-dev &>/dev/null
  FILE_VER=`curl -s ${github_token} https://api.github.com/repos/nginx/nginx/tags|grep name|head -1|grep -oE "([0-9]{1,3}\.){2}[0-9]{1,3}"`
  wget https://github.com/nginx/nginx/archive/release-${FILE_VER}.tar.gz
  tar xf release-${FILE_VER}.tar.gz
  cd nginx-release-${FILE_VER}
  git clone https://github.com/arut/nginx-dav-ext-module.git
  git clone https://github.com/openresty/headers-more-nginx-module.git
  ./auto/configure \
      --prefix=/etc/nginx \
      --sbin-path=/usr/sbin/nginx \
      --modules-path=/usr/lib/nginx/modules \
      --conf-path=/etc/nginx/nginx.conf \
      --error-log-path=/var/log/nginx/error.log \
      --http-log-path=/var/log/nginx/access.log \
      --pid-path=/run/nginx.pid \
      --lock-path=/run/nginx.lock \
      --http-client-body-temp-path=/var/cache/nginx/client_temp \
      --http-proxy-temp-path=/var/cache/nginx/proxy_temp \
      --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp \
      --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp \
      --http-scgi-temp-path=/var/cache/nginx/scgi_temp \
      --with-compat \
      --with-file-aio \
      --with-threads \
      --with-http_addition_module \
      --with-http_auth_request_module \
      --with-http_dav_module \
      --with-http_flv_module \
      --with-http_gunzip_module \
      --with-http_gzip_static_module \
      --with-http_mp4_module \
      --with-http_random_index_module \
      --with-http_realip_module \
      --with-http_secure_link_module \
      --with-http_slice_module \
      --with-http_ssl_module \
      --with-http_stub_status_module \
      --with-http_sub_module --with-http_v2_module \
      --with-mail \
      --with-mail_ssl_module \
      --with-stream \
      --with-stream_realip_module \
      --with-stream_ssl_module \
      --with-stream_ssl_preread_module \
      --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx/debian/debuild-base/nginx=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' \
      --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' \
      --add-module=nginx-dav-ext-module \
      --add-module=headers-more-nginx-module
  make -j$(nproc)
  strip -s ./objs/nginx
  make install
  cd /root/
  rm -rf /root/nginx-release-${FILE_VER}
  rm -rf /root/release-${FILE_VER}.tar.gz
}

compile_nginx
