#!/bin/bash

# shellcheck source=/dev/null
. "$(dirname "$0")/common.sh"

generate_farelogix_config() {
    local airline_code=$1
    local account_id=$2
    local prefix="WP_CHANNELS_FARELOGIX"

    info_log "Generating Farelogix config for airline_code: $airline_code, account_id: ${account_id:-none}"

    if [ -n "$account_id" ]; then
        prefix="${prefix}_${airline_code}_${account_id}"
    else
        prefix="${prefix}_${airline_code}"
    fi

    debug_log "Using environment variable prefix: $prefix"

    local host_var="${prefix}_HOST"
    local proxy_pass_var="${prefix}_PROXY_PASS"
    local host="${!host_var:-${airline_code,,}.farelogix.com}"
    local proxy_pass="${!proxy_pass_var:-https://${host}}"

    debug_log "Host: $host"
    debug_log "Proxy pass: $proxy_pass"

    local auth_vars=(
        "${prefix}_API_KEY"
        "${prefix}_AGENT"
        "${prefix}_USERNAME"
        "${prefix}_PASSWORD"
        "${prefix}_AGENT_USER"
        "${prefix}_AGENT_PASSWORD"
    )

    if check_any_vars "${auth_vars[@]}"; then
        debug_log "Found authentication variables for $prefix"
        if ! validate_env_vars "${auth_vars[@]}"; then
            error_log "Failed to validate environment variables for $prefix"
        fi

        (
            export HOST="$host"
            export PROXY_PASS="$proxy_pass"
            local api_key_var="${prefix}_API_KEY"
            local agent_var="${prefix}_AGENT"
            local username_var="${prefix}_USERNAME"
            local password_var="${prefix}_PASSWORD"
            local agent_user_var="${prefix}_AGENT_USER"
            local agent_password_var="${prefix}_AGENT_PASSWORD"

            export API_KEY="${!api_key_var}"
            export AGENT="${!agent_var}"
            export USERNAME="${!username_var}"
            export PASSWORD="${!password_var}"
            export AGENT_USER="${!agent_user_var}"
            export AGENT_PASSWORD="${!agent_password_var}"

            local airline_code_lower
            local account_id_lower
            airline_code_lower="$(echo "$airline_code" | tr '[:upper:]' '[:lower:]')"
            account_id_lower="$(echo "$account_id" | tr '[:upper:]' '[:lower:]')"

            if [ -n "$account_id" ]; then
                export LOCATION_PATH="${airline_code_lower}/${account_id_lower}"
            else
                export LOCATION_PATH="${airline_code_lower}"
            fi

            local output_file="/etc/nginx/includes/farelogix_${airline_code_lower}"
            [ -n "$account_id" ] && output_file="${output_file}_${account_id_lower}"
            output_file="${output_file}.conf"

            debug_log "Generating config file: $output_file"
            debug_log "Location path: $LOCATION_PATH"

            # shellcheck disable=SC2016
            generate_nginx_config \
                "/etc/nginx/templates/channels/farelogix.conf.template" \
                "$output_file" \
                '${LOCATION_PATH} ${HOST} ${PROXY_PASS} ${API_KEY} ${AGENT} ${USERNAME} ${PASSWORD} ${AGENT_USER} ${AGENT_PASSWORD}'

            debug_log "Config file generated successfully: $output_file"
        )
    else
        debug_log "No authentication variables found for $prefix"
    fi
}

debug_log "WP_CHANNELS_FARELOGIX_USE_ACCOUNT_IDS=${WP_CHANNELS_FARELOGIX_USE_ACCOUNT_IDS:-false}"

if [ "${WP_CHANNELS_FARELOGIX_USE_ACCOUNT_IDS:-false}" = "false" ]; then
    info_log "Running in legacy mode (no account IDs)"
    mapfile -t airline_codes < <(env | grep '^WP_CHANNELS_FARELOGIX_' | grep -v '_USE_ACCOUNT_IDS' | cut -d'_' -f4 | sort -u)
    for airline_code in "${airline_codes[@]}"; do
        debug_log "Found airline code: $airline_code"
        if ! generate_farelogix_config "$airline_code"; then
            error_log "Failed to generate config for airline code: $airline_code"
        fi
    done
else
    info_log "Running in new mode with account IDs"
    mapfile -t combinations < <(env | grep '^WP_CHANNELS_FARELOGIX_' | grep -v '_USE_ACCOUNT_IDS' | grep '_[^_]*_[^_]*_' | cut -d'_' -f4,5 | sort -u)
    for line in "${combinations[@]}"; do
        airline_code=$(echo "$line" | cut -d'_' -f1)
        account_id=$(echo "$line" | cut -d'_' -f2)
        debug_log "Found airline code: $airline_code with account ID: $account_id"
        if ! generate_farelogix_config "$airline_code" "$account_id"; then
            error_log "Failed to generate config for airline code: $airline_code with account ID: $account_id"
        fi
    done
fi
