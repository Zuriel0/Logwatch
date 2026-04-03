#!/usr/bin/env bash

validate_mac() {
  local mac="${1:-}"

  [[ -n "${mac}" ]] || {
    echo "Error: MAC vacía." >&2
    return 1
  }

  [[ "${mac}" =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || {
    echo "Error: formato de MAC inválido: ${mac}" >&2
    return 1
  }
}

normalize_mac() {
  local mac="${1:-}"
  echo "${mac,,}"
}

build_web_pattern() {
  local normalized_mac="${1:-}"
  echo "${normalized_mac//:/.*}"
}

build_radius_pattern() {
  local normalized_mac="${1:-}"
  echo "${normalized_mac}"
}