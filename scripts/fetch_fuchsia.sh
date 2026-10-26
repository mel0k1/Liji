#!/usr/bin/env bash
set -euo pipefail

LIJI_FETCH_VERSION="0.1.0"
INTEGRATION_URL="https://fuchsia.googlesource.com/integration"
MANIFEST="stem"
TARGET_DIR="${HOME}/liji-fuchsia"
SKIP_PREBUILTS=0
PREFLIGHT=0

usage() {
  cat <<EOF
Liji :: выкачка исходников Fuchsia (${LIJI_FETCH_VERSION})

usage: fetch_fuchsia.sh [опции]

  -d, --dir <path>      каталог выкачки (по умолчанию: ~/liji-fuchsia)
  -m, --manifest <name> манифест jiri (официальные):
                        stem (платформа + prebuilts, по умолчанию) |
                        flower (полный) | minimal (только integration)
      --no-prebuilts    не качать CIPD-пакеты (экономит ГБ, но нельзя собирать)
      --preflight       проверить машину утилитой ffx platform preflight
  -h, --help            показать справку

Требования: Linux x64, curl, file, git >= 2.31, unzip.
Диск: stem ~25-30 ГБ, flower ~60+ ГБ (с prebuilts); сборка потребует ещё 80-90 ГБ.
EOF
}

die() { echo "fetch_fuchsia: $1" >&2; exit 1; }

log() { echo "[fetch] $1"; }

check_deps() {
  for tool in curl file git unzip; do
    command -v "$tool" >/dev/null 2>&1 || die "нет утилиты: $tool (установите пакет)"
  done
  local major minor
  major=$(git --version | awk '{print $3}' | cut -d. -f1)
  minor=$(git --version | awk '{print $3}' | cut -d. -f2)
  if [ "$major" -lt 2 ] || { [ "$major" -eq 2 ] && [ "$minor" -lt 31 ]; }; then
    die "git >= 2.31 требуется, найдено $(git --version | awk '{print $3}')"
  fi
}

# Реальные требования к диску: stem с prebuilts ~25-30 ГБ, flower ~60+ ГБ.
disk_need_gb() {
  local base
  case "$MANIFEST" in
    minimal) base=1 ;;
    stem)    base=30 ;;
    flower)  base=60 ;;
  esac
  if [ "$SKIP_PREBUILTS" -eq 1 ]; then
    case "$MANIFEST" in
      stem)   base=15 ;;
      flower) base=35 ;;
    esac
  fi
  echo "$base"
}

check_disk() {
  local need_gb=$1 dir=$2
  mkdir -p "$dir"
  local avail_kb
  avail_kb=$(df -Pk "$dir" | awk 'NR==2 {print $4}')
  local avail_gb=$((avail_kb / 1024 / 1024))
  if [ "$avail_gb" -lt "$need_gb" ]; then
    die "свободно ${avail_gb} ГБ на $dir, нужно >= ${need_gb} ГБ"
  fi
  log "свободно ${avail_gb} ГБ, порог ${need_gb} ГБ пройден"
}

run_preflight() {
  log "запуск ffx platform preflight"
  local tmp
  tmp=$(mktemp -d)
  curl -sSL -o "$tmp/ffx" "https://storage.googleapis.com/fuchsia-ffx/ffx-linux-x64"
  chmod +x "$tmp/ffx"
  "$tmp/ffx" platform preflight
  rm -rf "$tmp"
}

bootstrap_jiri() {
  local arch cipd_platform
  arch=$(uname -m)
  case "$arch" in
    x86_64) cipd_platform="linux-amd64" ;;
    aarch64) cipd_platform="linux-arm64" ;;
    *) die "неподдерживаемая архитектура: $arch" ;;
  esac

  log "установка jiri через CIPD (${cipd_platform})"
  mkdir -p "$TARGET_DIR/.jiri_root/bin"
  curl -sSL -o "$TARGET_DIR/cipd" \
    "https://chrome-infra-packages.appspot.com/client?platform=${cipd_platform}&version=latest"
  chmod +x "$TARGET_DIR/cipd"

  printf 'fuchsia/tools/jiri/%s latest\n' "$cipd_platform" \
    > "$TARGET_DIR/jiri.ensure"
  "$TARGET_DIR/cipd" ensure -root "$TARGET_DIR/.jiri_root/bin" \
    -ensure-file "$TARGET_DIR/jiri.ensure"
  export PATH="$TARGET_DIR/.jiri_root/bin:$PATH"
  jiri version
}

fetch_sources() {
  local update_flags=()
  if [ "$SKIP_PREBUILTS" -eq 1 ]; then
    update_flags+=("-fetch-packages=false")
  fi

  cd "$TARGET_DIR"
  if [ -f .jiri_manifest ]; then
    log ".jiri_manifest уже есть — пропускаю init/import (повторный запуск)"
  else
    log "инициализация jiri в $TARGET_DIR"
    jiri init
    log "импорт манифеста $MANIFEST из $INTEGRATION_URL"
    jiri import -name=integration "$MANIFEST" "$INTEGRATION_URL"
  fi
  log "загрузка источников (это долго: сотни репозиториев)"
  jiri update "${update_flags[@]+"${update_flags[@]}"}"
  log "готово. объём выкачки:"
  du -sh "$TARGET_DIR"
}

print_next_steps() {
  cat <<EOF

[fetch] следующие шаги:
  export PATH="$TARGET_DIR/.jiri_root/bin:\$PATH"
  cd $TARGET_DIR
  jiri help && fx help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--dir) TARGET_DIR=$2; shift 2 ;;
    -m|--manifest) MANIFEST=$2; shift 2 ;;
    --no-prebuilts) SKIP_PREBUILTS=1; shift ;;
    --preflight) PREFLIGHT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage; die "неизвестный аргумент: $1" ;;
  esac
done

case "$MANIFEST" in
  minimal|stem|flower) ;;
  *) die "манифест должен быть minimal, stem или flower (получено: $MANIFEST)" ;;
esac

check_deps
if [ "$PREFLIGHT" -eq 1 ]; then
  run_preflight
fi

check_disk "$(disk_need_gb)" "$TARGET_DIR"

bootstrap_jiri
fetch_sources
print_next_steps
