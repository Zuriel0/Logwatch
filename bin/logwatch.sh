#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Cargar librerías
# shellcheck source=../lib/config.sh
source "${PROJECT_ROOT}/lib/config.sh"

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

  echo "Configuración cargada correctamente."
  echo "MAC recibida: ${mac}"
  echo "WEB habilitado: ${WEB_ENABLED}"
  echo "RADIUS habilitado: ${RADIUS_ENABLED}"
  echo "Servidor RADIUS activo: ${RADIUS_ACTIVE_SERVER}"

  echo
  echo "Próximo paso:"
  echo "1) validar/normalizar la MAC"
  echo "2) construir patrones web/radius"
  echo "3) lanzar orquestación"
}

main "$@"