#!/usr/bin/env bash

COLOR_RED=""
COLOR_YELLOW=""
COLOR_GREEN=""
COLOR_BLUE=""
COLOR_RESET=""

init_colors() {
  local enable="${ENABLE_COLOR:-true}"

  if [[ "${enable}" == "true" && -t 1 ]]; then
    COLOR_RED=$'\033[31m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_GREEN=$'\033[32m'
    COLOR_BLUE=$'\033[34m'
    COLOR_RESET=$'\033[0m'
  else
    COLOR_RED=""
    COLOR_YELLOW=""
    COLOR_GREEN=""
    COLOR_BLUE=""
    COLOR_RESET=""
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

highlight_mac_in_line() {
  local line="${1:-}"
  local mac="${2:-}"

  if [[ -z "${mac}" ]]; then
    echo "${line}"
    return 0
  fi

  if [[ -z "${COLOR_RED}" ]]; then
    echo "${line}"
    return 0
  fi

  sed -E "s/${mac}/${COLOR_RED}&${COLOR_RESET}/Ig" <<< "${line}"
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