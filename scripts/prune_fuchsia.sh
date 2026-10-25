#!/usr/bin/env bash
set -euo pipefail

LIJI_PRUNE_VERSION="0.1.0"
APPLY=0
AGGRESSIVE=0

usage() {
  cat <<EOF
Liji :: обрезка дерева исходников Fuchsia (${LIJI_PRUNE_VERSION})

usage: prune_fuchsia.sh <checkout> [--apply] [--aggressive]

  <checkout>     каталог выкачки Fuchsia (создан fetch_fuchsia.sh)
  --apply        реально удалять (по умолчанию только показать)
  --aggressive   дополнительно вырезать тестовые деревья

Безопасные цели: примеры, исходные доки, сэмплы Flutter, vendor-каталоги.
Агрессивные цели: тестовые деревья платформы.

Внимание: jiri update вернёт удалённое. Обрезку запускайте после
фиксации выкачки; если нужен jiri update — примите повторную обрезку.
Оставляем ядро системы: Zircon, CFv2, FIDL, Scenic, ввод, аудио,
сеть, файловые системы, драйверы, flutter runner.
EOF
}

die() { echo "prune_fuchsia: $1" >&2; exit 1; }

log() { echo "[prune] $1"; }

SAFE_DIRS=(
  "examples"
  "docs"
  "src/experiences"
  "src/samples"
  "vendor"
)

AGGRESSIVE_DIRS=(
  "src/tests"
  "src/testing"
  "scripts/tests"
  "tools/devshell/tests"
  "bundles/examples"
)

collect_targets() {
  local root=$1 list=$2
  local rel found=0 total=0
  for rel in $list; do
    if [ -e "$root/$rel" ]; then
      echo "$root/$rel"
      found=1
    fi
    total=$((total + 1))
  done
  [ "$found" -eq 1 ] || true
}

dir_size() {
  du -sB1 "$1" 2>/dev/null | awk '{print $1}' || echo 0
}

human_size() {
  local b=$1
  if [ "$b" -ge $((1024 * 1024 * 1024)) ]; then
    echo "$((b / 1024 / 1024 / 1024)) ГБ"
  elif [ "$b" -ge $((1024 * 1024)) ]; then
    echo "$((b / 1024 / 1024)) МБ"
  else
    echo "$((b / 1024)) КБ"
  fi
}

main() {
  local root=${1:-}
  shift || true

  while [ $# -gt 0 ]; do
    case "$1" in
      --apply) APPLY=1; shift ;;
      --aggressive) AGGRESSIVE=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) usage; die "неизвестный аргумент: $1" ;;
    esac
  done

  [ -n "$root" ] || { usage; die "укажите каталог выкачки"; }
  [ -d "$root" ] || die "каталог не найден: $root"
  [ -d "$root/.jiri_root" ] || die "$root не похож на выкачку Fuchsia (нет .jiri_root)"

  local list="${SAFE_DIRS[*]}"
  if [ "$AGGRESSIVE" -eq 1 ]; then
    list="${list} ${AGGRESSIVE_DIRS[*]}"
  fi

  local targets
  targets=$(collect_targets "$root" "$list")

  if [ -z "$targets" ]; then
    log "нечего вырезать: целевые каталоги не найдены"
    exit 0
  fi

  local total_bytes=0 t sz
  for t in $targets; do
    sz=$(dir_size "$t")
    total_bytes=$((total_bytes + sz))
    printf '  %-60s %s\n' "${t#$root/}" "$(human_size "$sz")"
  done
  log "итого к освобождению: $(human_size "$total_bytes")"

  if [ "$APPLY" -ne 1 ]; then
    log "dry-run: ничего не удалено. Добавьте --apply для удаления."
    exit 0
  fi

  for t in $targets; do
    log "удаляю ${t#$root/}"
    rm -rf "$t"
  done
  log "освобождено: $(human_size "$total_bytes")"
}

main "$@"
