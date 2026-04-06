#!/usr/bin/env bash

handle_interrupt() {
  print_warn "Interrupción recibida. Cerrando procesos..."
  cleanup_all_processes
  exit 130
}

setup_signal_handlers() {
  trap handle_interrupt INT TERM
}

wait_for_events() {
  local normalized_mac="${1:-}"
  local server_name=""
  local server_type=""
  local line=""

  while true; do
    if IFS=$'\x1f' read -r -t 1 server_name server_type line <&9; then
      case "${server_type}" in
        web)
          handle_web_match "${server_name}" "${line}" "${normalized_mac}"
          ;;
        web_status)
          handle_web_status "${server_name}" "${line}"
          ;;
        radius)
          handle_radius_match "${server_name}" "${line}" "${normalized_mac}"
          ;;
        radius_status)
          handle_radius_status "${server_name}" "${line}"
          ;;
        *)
          print_warn "Evento desconocido recibido: ${server_type}"
          ;;
      esac
      continue
    fi

    if ! any_watcher_running; then
      print_warn "No quedan procesos activos. Finalizando."
      break
    fi
  done
}

run_monitoring() {
  local normalized_mac="${1:-}"
  local web_pattern="${2:-}"
  local radius_pattern="${3:-}"

  setup_runtime_state
  open_event_bus
  setup_signal_handlers

  print_info "Estado runtime: ${RUNTIME_SESSION_DIR}"

  if is_enabled "${WEB_ENABLED}"; then
    start_web_watchers "${web_pattern}"
  else
    print_warn "No se iniciaron watchers WEB porque WEB_ENABLED está deshabilitado."
  fi

  if is_enabled "${RADIUS_ENABLED}"; then
    start_radius_watcher "${radius_pattern}"
  else
    print_warn "No se inició watcher RADIUS porque RADIUS_ENABLED está deshabilitado."
  fi

  print_success "Monitoreo concurrente iniciado."
  print_warn "Presiona Ctrl+C para detener."

  wait_for_events "${normalized_mac}"
  cleanup_all_processes
}