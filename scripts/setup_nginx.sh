#!/bin/bash

set -e

# shellcheck source=/dev/null
source "$(dirname "$0")/common.sh"

setup_tls_config() {
    debug_log "Setting up TLS configuration"

    if [ "${WP_SERVER_TLS_ENABLED}" = true ]; then
        debug_log "TLS is enabled, checking certificate configuration"

        if [ -z "$WP_SERVER_TLS_CERTIFICATE" ]; then
            error_log "TLS enabled but no certificate provided. Please set WP_SERVER_TLS_CERTIFICATE."
        fi

        if [ -z "$WP_SERVER_TLS_CERTIFICATE_KEY" ]; then
            error_log "TLS enabled but no certificate key provided. Please set WP_SERVER_TLS_CERTIFICATE_KEY."
        fi

        debug_log "Writing TLS certificate and key files"
        base64 -d <<< "$WP_SERVER_TLS_CERTIFICATE" > /etc/nginx/cert.crt
        base64 -d <<< "$WP_SERVER_TLS_CERTIFICATE_KEY" > /etc/nginx/cert.key
        dos2unix /etc/nginx/cert.crt /etc/nginx/cert.key

        WP_SERVER_TLS_PORT=${WP_SERVER_TLS_PORT:-18443}
        WP_SERVER_TLS_SERVER_NAME=${WP_SERVER_TLS_SERVER_NAME:-}

        debug_log "Using TLS port: ${WP_SERVER_TLS_PORT}"
        debug_log "Using TLS server name: ${WP_SERVER_TLS_SERVER_NAME:-<none>}"

        ssl_directives="listen ${WP_SERVER_TLS_PORT} ssl;"
        ssl_directives="${ssl_directives}  server_name ${WP_SERVER_TLS_SERVER_NAME};"
        ssl_directives="${ssl_directives}  ssl_certificate /etc/nginx/cert.crt;"
        ssl_directives="${ssl_directives}  ssl_certificate_key /etc/nginx/cert.key;"
        ssl_directives="${ssl_directives}  ssl_protocols TLSv1.2 TLSv1.3;"

        export WP_SERVER_TLS_DIRECTIVES="${ssl_directives}"
        info_log "TLS configuration completed successfully"
    else
        info_log "TLS is disabled, skipping TLS configuration"
    fi
}

setup_basic_auth() {
    debug_log "Setting up basic authentication"

    if [ -n "$WP_SERVER_HTTP_USER" ] && [ -n "$WP_SERVER_HTTP_PASS" ]; then
        debug_log "Basic auth credentials provided, creating .htpasswd file"
        htpasswd -c -b /etc/nginx/.htpasswd "${WP_SERVER_HTTP_USER}" "${WP_SERVER_HTTP_PASS}"
        chmod 644 /etc/nginx/.htpasswd
        export WP_SERVER_BASIC_AUTH="Restricted"
        info_log "Basic authentication enabled"
    else
        info_log "No basic auth credentials provided, disabling basic auth"
        export WP_SERVER_BASIC_AUTH="off"
    fi
}

setup_additional_includes() {
    debug_log "Setting up additional include files"

    WP_SERVER_PATH_INCLUDES=${WP_SERVER_PATH_INCLUDES:-}
    if [ -n "$WP_SERVER_PATH_INCLUDES" ]; then
        info_log "Processing additional include files"
        for include_file in $(echo "$WP_SERVER_PATH_INCLUDES" | tr "," "\n"); do
            if [ -f "$include_file" ]; then
                filename=$(basename "$include_file")
                target_path="/etc/nginx/includes/${filename}"

                if [ ! -f "$target_path" ]; then
                    debug_log "Creating symlink for $include_file to $target_path"
                    ln -s "$include_file" "$target_path"
                else
                    debug_log "File $filename already exists in includes directory"
                fi
            else
                warning_log "Warning: Include file $include_file not found"
            fi
        done
    else
        info_log "No additional include files specified"
    fi
}

process_channel_configs() {
    debug_log "Processing channel configurations"
    for script in "$(dirname "$0")"/channels/*.sh; do
        if [ -f "$script" ]; then
            debug_log "Processing channel script: $script"
            # shellcheck source=/dev/null
            source "$script"
        fi
    done
    debug_log "Finished processing channel configurations"
}

show_debug_info() {
    debug_log "Displaying detailed nginx configuration"
    echo "=== Main Nginx Configuration ==="
    cat /etc/nginx/nginx.conf
    echo
    echo "=== Include Files ==="
    for include in /etc/nginx/includes/*.conf; do
        if [ -f "$include" ]; then
            echo "--- $include ---"
            cat "$include"
            echo
        fi
    done
    debug_log "Finished displaying nginx configuration"
}

setup_nginx() {
    info_log "Starting nginx setup"

    export WP_SERVER_PORT=${WP_SERVER_PORT:-8080}
    export WP_SERVER_RESOLVER=${WP_SERVER_RESOLVER:-'8.8.8.8'}
    export DOLLAR='$'

    debug_log "Using server port: ${WP_SERVER_PORT}"
    debug_log "Using DNS resolver: ${WP_SERVER_RESOLVER}"

    setup_tls_config
    setup_basic_auth
    setup_additional_includes
    process_channel_configs

    debug_log "Generating main nginx configuration file"
    envsubst < /etc/nginx/templates/base.conf.template > /etc/nginx/nginx.conf

    debug_log "Nginx configuration generated"

    if [ "${WP_SERVER_DEBUG}" = true ]; then
        debug_log "Debug mode enabled, showing detailed configuration"
        printf " in debug mode\n"
        show_debug_info
    else
        printf "\n"
    fi

    info_log "Nginx setup completed"
}

setup_nginx

if [ "$1" == "start" ]; then
    info_log "Starting nginx server"
    exec nginx -c /etc/nginx/nginx.conf
fi
