#!/usr/bin/env bash

get_first_web_server_entry() {
  [[ "${#WEB_SERVERS[@]}" -gt 0 ]] || {
    echo "Error: no hay servidores web configurados." >&2
    return 1
  }

  echo "${WEB_SERVERS[0]}"
}

start_single_web_watcher() {
  local entry="${1:-}"
  local web_pattern="${2:-}"

  local web_name remote_cmd pid
  web_name="$(get_server_name "${entry}")"
  remote_cmd="$(build_web_remote_command "${web_pattern}")"

  print_info "Iniciando watcher WEB: ${web_name}"

  (
    run_remote_stream "${entry}" "${remote_cmd}" 2>&1 | while IFS= read -r line; do
      [[ -n "${line}" ]] || continue
      printf '%s\x1f%s\x1f%s\n' "${web_name}" "web" "${line}"
    done
  ) > "${EVENT_FIFO}" &

  pid=$!
  register_web_pid "${web_name}" "${pid}"
}

start_web_watchers() {
  local web_pattern="${1:-}"
  local entry

  for entry in "${WEB_SERVERS[@]}"; do
    start_single_web_watcher "${entry}" "${web_pattern}"
  done
}

handle_web_match() {
  local server_name="${1:-}"
  local line="${2:-}"
  local normalized_mac="${3:-}"

  local current_winner=""
  current_winner="$(get_web_winner || true)"

  print_match "${server_name}" "web" "${line}" "${normalized_mac}"

  if [[ -z "${current_winner}" ]]; then
    set_web_winner "${server_name}"
    print_success "Primer match WEB detectado en: ${server_name}"

    if [[ "${WEB_STOP_OTHER_SERVERS_ON_FIRST_MATCH}" == "true" ]]; then
      print_info "Cerrando otros servidores WEB. El ganador permanece activo: ${server_name}"
      stop_other_web_pids "${server_name}"
    fi
  fi
}

run_single_web_stream_test() {
  local normalized_mac="${1:-}"
  local web_pattern="${2:-}"

  local web_entry web_name remote_cmd

  web_entry="$(get_first_web_server_entry)" || return 1
  web_name="$(get_server_name "${web_entry}")"
  remote_cmd="$(build_web_remote_command "${web_pattern}")"

  print_info "Iniciando prueba de stream en WEB: ${web_name}"
  print_info "Comando remoto: ${remote_cmd}"
  print_warn "Presiona Ctrl+C para detener la prueba."

  while IFS= read -r line; do
    [[ -n "${line}" ]] || continue
    print_match "${web_name}" "web" "${line}" "${normalized_mac}"
  done < <(run_remote_stream "${web_entry}" "${remote_cmd}")
}