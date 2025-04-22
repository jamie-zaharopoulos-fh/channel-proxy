#!/bin/bash

# shellcheck source=/dev/null
. "$(dirname "$0")/common.sh"

setup_travelfusion() {
    debug_log "Setting up Travelfusion configuration"

    if [ -n "${WP_CHANNELS_TRAVELFUSION_LOGIN_ID}" ] || [ -n "${WP_CHANNELS_TRAVELFUSION_XML_LOGIN_ID}" ]; then
        info_log "Found Travelfusion credentials, proceeding with setup"

        if ! validate_env_vars "WP_CHANNELS_TRAVELFUSION_LOGIN_ID" "WP_CHANNELS_TRAVELFUSION_XML_LOGIN_ID" "WP_CHANNELS_TRAVELFUSION_SUPPLIER_PARAMETERS"; then
            error_log "Failed to validate required environment variables"
        fi

        export WP_CHANNELS_TRAVELFUSION_HOST=${WP_CHANNELS_TRAVELFUSION_HOST:-api.travelfusion.com}
        export WP_CHANNELS_TRAVELFUSION_PROXY_PASS=${WP_CHANNELS_TRAVELFUSION_PROXY_PASS:-${WP_SERVER_PROXY_PASS:-"https://${WP_CHANNELS_TRAVELFUSION_HOST}"}}

        debug_log "Using host: ${WP_CHANNELS_TRAVELFUSION_HOST}"
        debug_log "Using proxy pass: ${WP_CHANNELS_TRAVELFUSION_PROXY_PASS}"

        debug_log "Writing supplier parameters to tf_config.json"
        echo "${WP_CHANNELS_TRAVELFUSION_SUPPLIER_PARAMETERS:-}" > tf_config.json

        debug_log "Generating nginx configuration file"
        # shellcheck disable=SC2016
        generate_nginx_config \
            "/etc/nginx/templates/channels/travelfusion.conf.template" \
            "/etc/nginx/includes/travelfusion.conf" \
            '${WP_CHANNELS_TRAVELFUSION_LOGIN_ID} ${WP_CHANNELS_TRAVELFUSION_XML_LOGIN_ID} ${WP_CHANNELS_TRAVELFUSION_HOST} ${WP_CHANNELS_TRAVELFUSION_PROXY_PASS}'
        debug_log "Nginx configuration generated successfully"
    else
        info_log "No Travelfusion credentials found, skipping setup"
    fi
}

setup_travelfusion
