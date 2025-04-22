FROM openresty/openresty:1.25.3.1-4-focal

RUN apt-get update && apt-get install --no-install-recommends -y \
    apache2-utils \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/nginx/includes /etc/nginx/templates

COPY templates /etc/nginx/templates
COPY scripts /usr/local/bin/scripts
COPY travelfusion.lua /

RUN chmod -R +x /usr/local/bin/scripts

WORKDIR /

STOPSIGNAL SIGTERM

CMD ["/usr/local/bin/scripts/setup_nginx.sh", "start"]
