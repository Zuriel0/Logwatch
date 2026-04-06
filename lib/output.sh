#!/usr/bin/env bash

COLOR_RED=""
COLOR_YELLOW=""
COLOR_GREEN=""
COLOR_BLUE=""
COLOR_RESET=""

init_colors() {
  local enable="${ENABLE_COLOR:-true}"
  local force="${FORCE_COLOR:-false}"

  enable="${enable,,}"
  force="${force,,}"

  if [[ "${enable}" == "true" || "${enable}" == "1" || "${enable}" == "yes" ]]; then
    if [[ -t 1 || "${force}" == "true" || "${force}" == "1" || "${force}" == "yes" ]]; then
      COLOR_RED=$'\033[31m'
      COLOR_YELLOW=$'\033[33m'
      COLOR_GREEN=$'\033[32m'
      COLOR_BLUE=$'\033[34m'
      COLOR_RESET=$'\033[0m'
    fi
  fi
}

print_info() {
  local msg="${1:-}"
  printf '%s[INFO]%s %s\n' "${COLOR_BLUE}" "${COLOR_RESET}" "${msg}"
}

print_success() {
  local msg="${1:-}"
  printf '%s[OK]%s %s\n' "${COLOR_GREEN}" "${COLOR_RESET}" "${msg}"
}

print_warn() {
  local msg="${1:-}"
  printf '%s[WARN]%s %s\n' "${COLOR_YELLOW}" "${COLOR_RESET}" "${msg}"
}

print_error() {
  local msg="${1:-}"
  printf '%s[ERROR]%s %s\n' "${COLOR_RED}" "${COLOR_RESET}" "${msg}" >&2
}

print_server_status() {
  local server_name="${1:-}"
  local server_type="${2:-}"
  local status="${3:-}"

  printf '[%s][%s][STATUS] %s\n' "${server_name}" "${server_type}" "${status}"
}

escape_sed_pattern() {
  local text="${1:-}"
  printf '%s' "${text}" | sed -e 's/[][\/.^$*+?(){}|]/\\&/g'
}

build_mac_variants() {
  local mac="${1:-}"
  local raw=""
  local dashed=""
  local dotted=""
  local urlenc=""

  raw="${mac//:/}"
  dashed="${mac//:/-}"
  urlenc="${mac//:/%3a}"

  if [[ "${#raw}" -eq 12 ]]; then
    dotted="${raw:0:4}.${raw:4:4}.${raw:8:4}"
  fi

  printf '%s\n' "${mac}"
  printf '%s\n' "${raw}"
  printf '%s\n' "${dashed}"
  [[ -n "${dotted}" ]] && printf '%s\n' "${dotted}"
  printf '%s\n' "${urlenc}"
}

highlight_mac_in_line() {
  local line="${1:-}"
  local mac="${2:-}"

  [[ -n "${mac}" ]] || {
    echo "${line}"
    return 0
  }

  [[ -n "${COLOR_RED}" ]] || {
    echo "${line}"
    return 0
  }

  local result="${line}"
  local variant=""
  local escaped=""

  while IFS= read -r variant; do
    [[ -n "${variant}" ]] || continue
    escaped="$(escape_sed_pattern "${variant}")"
    result="$(printf '%s\n' "${result}" | sed -E "s/${escaped}/${COLOR_RED}&${COLOR_RESET}/Ig")"
  done < <(build_mac_variants "${mac}")

  echo "${result}"
}

print_match() {
  local server_name="${1:-}"
  local server_type="${2:-}"
  local line="${3:-}"
  local mac="${4:-}"

  local rendered_line
  rendered_line="$(highlight_mac_in_line "${line}" "${mac}")"

  printf '[%s][%s] %s\n' "${server_name}" "${server_type}" "${rendered_line}"
}