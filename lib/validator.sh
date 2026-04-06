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

build_mac_raw() {
  local mac="${1:-}"
  echo "${mac//:/}"
}

build_mac_dashed() {
  local mac="${1:-}"
  echo "${mac//:/-}"
}

build_mac_dotted() {
  local mac="${1:-}"
  local raw
  raw="${mac//:/}"

  if [[ "${#raw}" -eq 12 ]]; then
    echo "${raw:0:4}.${raw:4:4}.${raw:8:4}"
  fi
}

build_mac_urlencoded() {
  local mac="${1:-}"
  echo "${mac//:/%3a}"
}

build_web_pattern() {
  local normalized_mac="${1:-}"
  local raw dashed dotted urlenc

  raw="$(build_mac_raw "${normalized_mac}")"
  dashed="$(build_mac_dashed "${normalized_mac}")"
  dotted="$(build_mac_dotted "${normalized_mac}")"
  urlenc="$(build_mac_urlencoded "${normalized_mac}")"

  echo "(${normalized_mac}|${raw}|${dashed}|${dotted}|${urlenc})"
}

build_radius_pattern() {
  local normalized_mac="${1:-}"
  echo "${normalized_mac}"
}