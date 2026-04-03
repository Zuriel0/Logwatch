#!/usr/bin/env bash

build_ssh_target() {
  local entry="${1:-}"

  local mode alias host user
  mode="$(get_server_mode "${entry}")"
  alias="$(get_server_alias "${entry}")"
  host="$(get_server_host "${entry}")"
  user="$(get_server_user "${entry}")"

  if [[ "${mode}" == "alias" ]]; then
    echo "${alias}"
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

run_ssh_command() {
  local entry="${1:-}"
  local remote_cmd="${2:-}"

  local target mode port_args
  local -a common_opts ssh_cmd

  target="$(build_ssh_target "${entry}")" || return 1
  mode="$(get_server_mode "${entry}")"
  port_args="$(build_ssh_port_args "${entry}")"

  read -r -a common_opts <<< "${SSH_COMMON_OPTIONS:-}"

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
  echo "tail -F ${WEB_LOG_PATH} | grep --line-buffered -i '${web_pattern}'"
}

build_radius_remote_command() {
  local radius_pattern="${1:-}"
  echo "tail -F ${RADIUS_LOG_PATH} | grep --line-buffered -i '${radius_pattern}'"
}