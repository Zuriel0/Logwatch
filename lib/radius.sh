#!/usr/bin/env bash

start_radius_watcher() {
  local radius_pattern="${1:-}"

  local radius_entry radius_name remote_cmd pid
  radius_entry="$(find_radius_server_entry)" || {
    print_error "No se pudo resolver el servidor RADIUS activo."
    return 1
  }

  radius_name="$(get_server_name "${radius_entry}")"
  remote_cmd="$(build_radius_remote_command "${radius_pattern}")"

  print_info "Iniciando watcher RADIUS: ${radius_name}"

  (
    run_remote_stream "${radius_entry}" "${remote_cmd}" 2>&1 | while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      printf '%s\x1f%s\x1f%s\n' "${radius_name}" "radius" "${line}"
    done
  ) > "${EVENT_FIFO}" &

  pid=$!
  register_radius_pid "${radius_name}" "${pid}"
}

handle_radius_match() {
  local server_name="${1:-}"
  local line="${2:-}"
  local normalized_mac="${3:-}"

  print_match "${server_name}" "radius" "${line}" "${normalized_mac}"
}