#!/usr/bin/env bash

get_first_web_server_entry() {
  [[ "${#WEB_SERVERS[@]}" -gt 0 ]] || {
    echo "Error: no hay servidores web configurados." >&2
    return 1
  }

  echo "${WEB_SERVERS[0]}"
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