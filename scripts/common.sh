#!/bin/bash

export WP_SERVER_DEBUG=${WP_SERVER_DEBUG:-false}

generate_nginx_config() {
    local template="$1"
    local output="$2"
    local vars="$3"

    envsubst "$vars" < "$template" > "$output"
}

validate_env_vars() {
    local vars=("$@")
    local missing=()

    debug_log "Validating required environment variables: ${vars[*]}"

    for var in "${vars[@]}"; do
        debug_log "Checking variable '$var' with value '${!var}'"
        if [ -z "${!var}" ]; then
            missing+=("$var")
            debug_log "Variable '$var' is missing or empty"
        else
            debug_log "Variable '$var' is valid"
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        warning_log "Validation failed - missing variables: ${missing[*]}"
        return 1
    fi

    debug_log "All required variables are valid"
    return 0
}

check_any_vars() {
    local vars=("$@")

    debug_log "Checking if any of these variables are set: ${vars[*]}"

    for var in "${vars[@]}"; do
        debug_log "Checking variable '$var' with value '${!var}'"
        if [ -n "${!var}" ]; then
            debug_log "Found set variable '$var'"
            return 0
        fi
    done

    debug_log "None of the variables are set"
    return 1
}

debug_log() {
    if [ "${WP_SERVER_DEBUG}" = true ]; then
        echo "[DEBUG] $1"
    fi
}

info_log() {
    echo "[INFO] $1"
}

warning_log() {
    echo "[WARNING] $1"
}

error_log() {
    echo "[ERROR] $1"
    exit 1
}
