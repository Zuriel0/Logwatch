#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# shellcheck source=../lib/config.sh
source "${PROJECT_ROOT}/lib/config.sh"
# shellcheck source=../lib/validator.sh
source "${PROJECT_ROOT}/lib/validator.sh"
# shellcheck source=../lib/ssh.sh
source "${PROJECT_ROOT}/lib/ssh.sh"
# shellcheck source=../lib/output.sh
source "${PROJECT_ROOT}/lib/output.sh"
# shellcheck source=../lib/process.sh
source "${PROJECT_ROOT}/lib/process.sh"
# shellcheck source=../lib/web.sh
source "${PROJECT_ROOT}/lib/web.sh"
# shellcheck source=../lib/radius.sh
source "${PROJECT_ROOT}/lib/radius.sh"
# shellcheck source=../lib/orchestrator.sh
source "${PROJECT_ROOT}/lib/orchestrator.sh"

usage() {
  cat <<'EOF'
Uso:
  ./bin/logwatch.sh --mac aa:bb:cc:dd:ee:ff [--config ./config/servers.conf] [--test-single-web-stream]

Opciones:
  --mac                     MAC a buscar (obligatorio)
  --config                  Ruta al archivo de configuración
  --test-single-web-stream  Ejecuta una prueba real de stream contra el primer WEB
  --help                    Muestra esta ayuda
EOF
}

main() {
  local mac=""
  local normalized_mac=""
  local web_pattern=""
  local radius_pattern=""
  local config_path="${PROJECT_ROOT}/config/servers.conf"
  local test_single_web_stream="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mac)
        mac="${2:-}"
        shift 2
        ;;
      --config)
        config_path="${2:-}"
        shift 2
        ;;
      --test-single-web-stream)
        test_single_web_stream="true"
        shift
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "Error: argumento no reconocido: $1" >&2
        usage
        exit 1
        ;;
    esac
  done

  if [[ -z "${mac}" ]]; then
    echo "Error: debes indicar --mac" >&2
    usage
    exit 1
  fi

  load_config "${config_path}"
  validate_config
  init_colors

  validate_mac "${mac}"
  normalized_mac="$(normalize_mac "${mac}")"
  web_pattern="$(build_web_pattern "${normalized_mac}")"
  radius_pattern="$(build_radius_pattern "${normalized_mac}")"

  print_success "Configuración cargada correctamente."
  print_info "WEB_ENABLED leído como: '${WEB_ENABLED}'"
  print_info "RADIUS_ENABLED leído como: '${RADIUS_ENABLED}'"
  print_info "MAC normalizada: ${normalized_mac}"
  print_info "Patrón WEB: ${web_pattern}"
  print_info "Patrón RADIUS: ${radius_pattern}"

  if is_enabled "${WEB_ENABLED}"; then
    local first_web_entry first_web_name
    first_web_entry="${WEB_SERVERS[0]}"
    first_web_name="$(get_server_name "${first_web_entry}")"

    print_info "Probando conexión SSH al primer WEB: ${first_web_name}"
    test_ssh_connection "${first_web_entry}" >/dev/null
    print_success "Conexión SSH OK con ${first_web_name}"
  else
    print_warn "Grupo WEB deshabilitado por configuración."
  fi

  if is_enabled "${RADIUS_ENABLED}"; then
    local radius_entry radius_name
    radius_entry="$(find_radius_server_entry)"
    radius_name="$(get_server_name "${radius_entry}")"

    print_info "Servidor RADIUS activo configurado: ${radius_name}"
    print_info "Probando conexión SSH al RADIUS activo: ${radius_name}"
    test_ssh_connection "${radius_entry}" >/dev/null
    print_success "Conexión SSH OK con ${radius_name}"
  else
    print_warn "Grupo RADIUS deshabilitado por configuración."
  fi

  if [[ "${test_single_web_stream}" == "true" ]]; then
    print_info "Entrando en modo de prueba real para un solo WEB."
    run_single_web_stream_test "${normalized_mac}" "${web_pattern}"
    exit 0
  fi

  run_monitoring "${normalized_mac}" "${web_pattern}" "${radius_pattern}"
}

main "$@"