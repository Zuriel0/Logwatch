#!/usr/bin/env bash

normalize_bool() {
  local value="${1:-}"
  value="${value//$'\r'/}"
  value="${value,,}"
  echo "${value}"
}

is_enabled() {
  local value
  value="$(normalize_bool "${1:-}")"

  case "${value}" in
    true|1|yes|y|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

load_config() {
  local config_path="${1:-}"

  if [[ -z "${config_path}" ]]; then
    echo "Error: load_config requiere una ruta de archivo." >&2
    return 1
  fi

  if [[ ! -f "${config_path}" ]]; then
    echo "Error: archivo de configuración no encontrado: ${config_path}" >&2
    return 1
  fi

  # shellcheck disable=SC1090
  source "${config_path}"
}

validate_config() {
  validate_required_globals
  validate_web_config
  validate_radius_config
  validate_radius_active_server_exists
}

validate_required_globals() {
  local required_vars=(
    CONNECT_TIMEOUT_SECONDS
    SSH_COMMON_OPTIONS
    STATE_DIR
    WEB_ENABLED
    RADIUS_ENABLED
  )

  local var_name
  for var_name in "${required_vars[@]}"; do
    if [[ -z "${!var_name+x}" ]]; then
      echo "Error: falta variable requerida en config: ${var_name}" >&2
      return 1
    fi
  done
}

validate_web_config() {
  is_enabled "${WEB_ENABLED}" || return 0

  [[ -n "${WEB_LOG_PATH:-}" ]] || {
    echo "Error: WEB_LOG_PATH es obligatorio cuando WEB_ENABLED=true" >&2
    return 1
  }

  [[ -n "${WEB_STOP_OTHER_SERVERS_ON_FIRST_MATCH:-}" ]] || {
    echo "Error: WEB_STOP_OTHER_SERVERS_ON_FIRST_MATCH es obligatorio." >&2
    return 1
  }

  if ! declare -p WEB_SERVERS >/dev/null 2>&1; then
    echo "Error: WEB_SERVERS no está definido." >&2
    return 1
  fi

  [[ "${#WEB_SERVERS[@]}" -gt 0 ]] || {
    echo "Error: WEB_SERVERS no puede estar vacío cuando WEB_ENABLED=true" >&2
    return 1
  }

  local entry
  for entry in "${WEB_SERVERS[@]}"; do
    validate_server_entry "${entry}" "web"
  done
}

validate_radius_config() {
  is_enabled "${RADIUS_ENABLED}" || return 0

  [[ -n "${RADIUS_LOG_PATH:-}" ]] || {
    echo "Error: RADIUS_LOG_PATH es obligatorio cuando RADIUS_ENABLED=true" >&2
    return 1
  }

  [[ -n "${RADIUS_ACTIVE_SERVER:-}" ]] || {
    echo "Error: RADIUS_ACTIVE_SERVER es obligatorio cuando RADIUS_ENABLED=true" >&2
    return 1
  }

  if ! declare -p RADIUS_SERVERS >/dev/null 2>&1; then
    echo "Error: RADIUS_SERVERS no está definido." >&2
    return 1
  fi

  [[ "${#RADIUS_SERVERS[@]}" -gt 0 ]] || {
    echo "Error: RADIUS_SERVERS no puede estar vacío cuando RADIUS_ENABLED=true" >&2
    return 1
  }

  local entry
  for entry in "${RADIUS_SERVERS[@]}"; do
    validate_server_entry "${entry}" "radius"
  done
}

validate_radius_active_server_exists() {
  is_enabled "${RADIUS_ENABLED}" || return 0

  local found="false"
  local entry name

  for entry in "${RADIUS_SERVERS[@]}"; do
    name="$(get_server_field "${entry}" 1)"
    if [[ "${name}" == "${RADIUS_ACTIVE_SERVER}" ]]; then
      found="true"
      break
    fi
  done

  if [[ "${found}" != "true" ]]; then
    echo "Error: RADIUS_ACTIVE_SERVER='${RADIUS_ACTIVE_SERVER}' no existe en RADIUS_SERVERS" >&2
    return 1
  fi
}

validate_server_entry() {
  local entry="${1:-}"
  local group_name="${2:-}"

  local name mode ssh_alias host user port
  name="$(get_server_field "${entry}" 1)"
  mode="$(get_server_field "${entry}" 2)"
  ssh_alias="$(get_server_field "${entry}" 3)"
  host="$(get_server_field "${entry}" 4)"
  user="$(get_server_field "${entry}" 5)"
  port="$(get_server_field "${entry}" 6)"

  [[ -n "${name}" ]] || {
    echo "Error: entrada ${group_name} sin nombre: ${entry}" >&2
    return 1
  }

  [[ "${mode}" == "alias" || "${mode}" == "direct" ]] || {
    echo "Error: servidor '${name}' tiene connection_mode inválido: '${mode}'" >&2
    return 1
  }

  if [[ "${mode}" == "alias" ]]; then
    [[ -n "${ssh_alias}" ]] || {
      echo "Error: servidor '${name}' en modo alias requiere ssh_alias" >&2
      return 1
    }
  fi

  if [[ "${mode}" == "direct" ]]; then
    [[ -n "${host}" ]] || {
      echo "Error: servidor '${name}' en modo direct requiere host" >&2
      return 1
    }

    [[ -n "${user}" ]] || {
      echo "Error: servidor '${name}' en modo direct requiere user" >&2
      return 1
    }

    [[ -n "${port}" ]] || {
      echo "Error: servidor '${name}' en modo direct requiere port" >&2
      return 1
    }
  fi
}

get_server_field() {
  local entry="${1:-}"
  local field_number="${2:-}"
  awk -F'|' -v n="${field_number}" '{print $n}' <<< "${entry}"
}

get_server_name() {
  local entry="${1:-}"
  get_server_field "${entry}" 1
}

get_server_mode() {
  local entry="${1:-}"
  get_server_field "${entry}" 2
}

get_server_alias() {
  local entry="${1:-}"
  get_server_field "${entry}" 3
}

get_server_host() {
  local entry="${1:-}"
  get_server_field "${entry}" 4
}

get_server_user() {
  local entry="${1:-}"
  get_server_field "${entry}" 5
}

get_server_port() {
  local entry="${1:-}"
  get_server_field "${entry}" 6
}

find_radius_server_entry() {
  local entry name

  for entry in "${RADIUS_SERVERS[@]}"; do
    name="$(get_server_name "${entry}")"
    if [[ "${name}" == "${RADIUS_ACTIVE_SERVER}" ]]; then
      echo "${entry}"
      return 0
    fi
  done

  return 1
}