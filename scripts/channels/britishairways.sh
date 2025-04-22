#!/bin/bash

# shellcheck source=/dev/null
. "$(dirname "$0")/common.sh"

setup_britishairways() {
    debug_log "Setting up British Airways configuration"

    if check_any_vars "WP_CHANNELS_BA_API_KEY"; then
        info_log "Found British Airways API key, proceeding with setup"

        if ! validate_env_vars "WP_CHANNELS_BA_API_KEY"; then
            error_log "Failed to validate required environment variables"
        fi

        export WP_CHANNELS_BA_HOST=${WP_CHANNELS_BA_HOST:-api.ba.com}
        export WP_CHANNELS_BA_PROXY_PASS=${WP_CHANNELS_BA_PROXY_PASS:-${WP_SERVER_PROXY_PASS:-"https://${WP_CHANNELS_BA_HOST}"}}

        debug_log "Using host: ${WP_CHANNELS_BA_HOST}"
        debug_log "Using proxy pass: ${WP_CHANNELS_BA_PROXY_PASS}"

        debug_log "Generating nginx configuration file"
        # shellcheck disable=SC2016
        generate_nginx_config \
            "/etc/nginx/templates/channels/britishairways.conf.template" \
            "/etc/nginx/includes/britishairways.conf" \
            '${WP_CHANNELS_BA_PROXY_PASS} ${WP_CHANNELS_BA_HOST} ${WP_CHANNELS_BA_API_KEY}'
        debug_log "Nginx configuration generated successfully"
    else
        info_log "No British Airways API key found, skipping setup"
    fi
}

setup_britishairways
