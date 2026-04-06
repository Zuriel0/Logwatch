#!/usr/bin/env bash

build_ssh_target() {
  local entry="${1:-}"

  local mode ssh_alias host user
  mode="$(get_server_mode "${entry}")"
  ssh_alias="$(get_server_alias "${entry}")"
  host="$(get_server_host "${entry}")"
  user="$(get_server_user "${entry}")"

  if [[ "${mode}" == "alias" ]]; then
    echo "${ssh_alias}"
    return 0
  fi

  if [[ "${mode}" == "direct" ]]; then
    echo "${user}@${host}"
    return 0
  fi

  echo "Error: modo de conexión no soportado: ${mode}" >&2
  return 1
}

build_ssh_port_args() {
  local entry="${1:-}"
  local mode port
  mode="$(get_server_mode "${entry}")"
  port="$(get_server_port "${entry}")"

  if [[ "${mode}" == "direct" && -n "${port}" ]]; then
    echo "-p ${port}"
  fi
}

build_effective_ssh_options() {
  local timeout="${CONNECT_TIMEOUT_SECONDS:-20}"

  if [[ -n "${SSH_COMMON_OPTIONS:-}" ]]; then
    echo "${SSH_COMMON_OPTIONS}"
  else
    echo "-o BatchMode=yes -o ConnectTimeout=${timeout}"
  fi
}

run_ssh_command() {
  local entry="${1:-}"
  local remote_cmd="${2:-}"

  local target mode port_args effective_opts
  local -a common_opts ssh_cmd

  target="$(build_ssh_target "${entry}")" || return 1
  mode="$(get_server_mode "${entry}")"
  port_args="$(build_ssh_port_args "${entry}")"
  effective_opts="$(build_effective_ssh_options)"

  read -r -a common_opts <<< "${effective_opts}"

  ssh_cmd=(ssh "${common_opts[@]}")

  if [[ "${mode}" == "direct" && -n "${port_args}" ]]; then
    # shellcheck disable=SC2206
    local extra_port_args=( ${port_args} )
    ssh_cmd+=("${extra_port_args[@]}")
  fi

  ssh_cmd+=("${target}" "${remote_cmd}")

  "${ssh_cmd[@]}"
}

test_ssh_connection() {
  local entry="${1:-}"
  run_ssh_command "${entry}" "echo SSH_OK"
}

run_remote_stream() {
  local entry="${1:-}"
  local remote_cmd="${2:-}"
  run_ssh_command "${entry}" "${remote_cmd}"
}

build_web_remote_command() {
  local web_pattern="${1:-}"
  echo "tail -F ${WEB_LOG_PATH} | grep --line-buffered -Ei '${web_pattern}'"
}

build_radius_remote_command() {
  local radius_pattern="${1:-}"
  echo "tail -F ${RADIUS_LOG_PATH} | grep --line-buffered -i '${radius_pattern}'"
}