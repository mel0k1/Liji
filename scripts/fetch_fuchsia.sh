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
  -m, --manifest <name> манифест jiri: stem (лёгкий, по умолчанию) | flower (полный)
      --no-prebuilts    не качать CIPD-пакеты (экономит ГБ, но нельзя собирать)
      --preflight       проверить машину утилитой ffx platform preflight
  -h, --help            показать справку

Требования: Linux x64, curl, file, git >= 2.31, unzip.
Диск: stem ~3 ГБ, flower ~5 ГБ; сборка потребует ещё 80-90 ГБ.
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

  printf 'fuchsia/internal/jiri/%s latest\n' "$cipd_platform" \
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

  log "инициализация jiri в $TARGET_DIR"
  cd "$TARGET_DIR"
  jiri init
  log "импорт манифеста $MANIFEST из $INTEGRATION_URL"
  jiri import -name=integration "$MANIFEST" "$INTEGRATION_URL"
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
  (опционально) scripts/prune_fuchsia.sh $TARGET_DIR --apply
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
  stem|flower) ;;
  *) die "манифест должен быть stem или flower (получено: $MANIFEST)" ;;
esac

check_deps
if [ "$PREFLIGHT" -eq 1 ]; then
  run_preflight
fi

case "$MANIFEST" in
  stem) check_disk 4 "$TARGET_DIR" ;;
  flower) check_disk 6 "$TARGET_DIR" ;;
esac

bootstrap_jiri
fetch_sources
print_next_steps
