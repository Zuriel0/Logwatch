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

usage() {
  cat <<'EOF'
Uso:
  ./bin/logwatch.sh --mac aa:bb:cc:dd:ee:ff [--config ./config/servers.conf]

Opciones:
  --mac       MAC a buscar (obligatorio)
  --config    Ruta al archivo de configuración
  --help      Muestra esta ayuda
EOF
}

main() {
  local mac=""
  local normalized_mac=""
  local web_pattern=""
  local radius_pattern=""
  local config_path="${PROJECT_ROOT}/config/servers.conf"

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

  validate_mac "${mac}"
  normalized_mac="$(normalize_mac "${mac}")"
  web_pattern="$(build_web_pattern "${normalized_mac}")"
  radius_pattern="$(build_radius_pattern "${normalized_mac}")"

  echo "Configuración cargada correctamente."
  echo "MAC normalizada: ${normalized_mac}"
  echo "Patrón WEB: ${web_pattern}"
  echo "Patrón RADIUS: ${radius_pattern}"
  echo

  if [[ "${WEB_ENABLED}" == "true" ]]; then
    local first_web_entry first_web_name web_cmd
    first_web_entry="${WEB_SERVERS[0]}"
    first_web_name="$(get_server_name "${first_web_entry}")"
    web_cmd="$(build_web_remote_command "${web_pattern}")"

    echo "Probando conexión SSH al primer WEB: ${first_web_name}"
    test_ssh_connection "${first_web_entry}"
    echo "Conexión SSH OK con ${first_web_name}"
    echo

    echo "Comando remoto WEB de prueba:"
    echo "${web_cmd}"
  fi

  if [[ "${RADIUS_ENABLED}" == "true" ]]; then
    local radius_entry radius_name radius_cmd
    radius_entry="$(find_radius_server_entry)"
    radius_name="$(get_server_name "${radius_entry}")"
    radius_cmd="$(build_radius_remote_command "${radius_pattern}")"

    echo
    echo "Probando conexión SSH al RADIUS activo: ${radius_name}"
    test_ssh_connection "${radius_entry}"
    echo "Conexión SSH OK con ${radius_name}"
    echo

    echo "Comando remoto RADIUS de prueba:"
    echo "${radius_cmd}"
  fi
}

main "$@"