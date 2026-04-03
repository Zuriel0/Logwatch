#!/usr/bin/env bash

declare -Ag WEB_WATCHER_PIDS=()
RADIUS_WATCHER_PID=""
RADIUS_WATCHER_NAME=""

EVENT_FIFO=""
WEB_WINNER_FILE=""
RUNTIME_SESSION_DIR=""

setup_runtime_state() {
  local timestamp
  timestamp="$(date +%Y%m%d_%H%M%S)"

  mkdir -p "${STATE_DIR}"
  RUNTIME_SESSION_DIR="${STATE_DIR}/session_${$}_${timestamp}"
  mkdir -p "${RUNTIME_SESSION_DIR}"

  EVENT_FIFO="${RUNTIME_SESSION_DIR}/events.fifo"
  WEB_WINNER_FILE="${RUNTIME_SESSION_DIR}/web_winner"

  mkfifo "${EVENT_FIFO}"
}

open_event_bus() {
  exec 9<>"${EVENT_FIFO}"
}

close_event_bus() {
  exec 9>&- || true
  exec 9<&- || true
}

set_web_winner() {
  local server_name="${1:-}"
  printf '%s\n' "${server_name}" > "${WEB_WINNER_FILE}"
}

get_web_winner() {
  if [[ -f "${WEB_WINNER_FILE}" ]]; then
    cat "${WEB_WINNER_FILE}"
  fi
}

register_web_pid() {
  local server_name="${1:-}"
  local pid="${2:-}"
  WEB_WATCHER_PIDS["${server_name}"]="${pid}"
}

register_radius_pid() {
  local server_name="${1:-}"
  local pid="${2:-}"
  RADIUS_WATCHER_NAME="${server_name}"
  RADIUS_WATCHER_PID="${pid}"
}

is_pid_running() {
  local pid="${1:-}"
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null
}

stop_pid() {
  local pid="${1:-}"

  [[ -n "${pid}" ]] || return 0
  is_pid_running "${pid}" || return 0

  kill -TERM "${pid}" 2>/dev/null || true
  pkill -TERM -P "${pid}" 2>/dev/null || true

  local i
  for i in {1..10}; do
    if ! is_pid_running "${pid}"; then
      wait "${pid}" 2>/dev/null || true
      return 0
    fi
    sleep 0.2
  done

  kill -KILL "${pid}" 2>/dev/null || true
  pkill -KILL -P "${pid}" 2>/dev/null || true
  wait "${pid}" 2>/dev/null || true
}

stop_other_web_pids() {
  local winner_name="${1:-}"
  local server_name pid

  for server_name in "${!WEB_WATCHER_PIDS[@]}"; do
    [[ "${server_name}" == "${winner_name}" ]] && continue
    pid="${WEB_WATCHER_PIDS[${server_name}]}"
    stop_pid "${pid}"
  done
}

stop_all_web_pids() {
  local server_name pid

  for server_name in "${!WEB_WATCHER_PIDS[@]}"; do
    pid="${WEB_WATCHER_PIDS[${server_name}]}"
    stop_pid "${pid}"
  done
}

stop_radius_pid() {
  stop_pid "${RADIUS_WATCHER_PID}"
}

any_watcher_running() {
  local server_name pid

  for server_name in "${!WEB_WATCHER_PIDS[@]}"; do
    pid="${WEB_WATCHER_PIDS[${server_name}]}"
    if is_pid_running "${pid}"; then
      return 0
    fi
  done

  if is_pid_running "${RADIUS_WATCHER_PID}"; then
    return 0
  fi

  return 1
}

cleanup_runtime_state() {
  close_event_bus

  if [[ -n "${RUNTIME_SESSION_DIR}" && -d "${RUNTIME_SESSION_DIR}" ]]; then
    rm -rf "${RUNTIME_SESSION_DIR}"
  fi
}

cleanup_all_processes() {
  stop_all_web_pids
  stop_radius_pid
  cleanup_runtime_state
}