#!/usr/bin/env bash
# Liji :: boot_smoke.sh — головной тест загрузки образа в FEMU (для CI).
#
# Запускает собранный образ без экрана, пишет serial-вывод в лог и ждёт
# появления маркера загрузки. Работает без KVM (TCG) — медленно, но для
# smoke-теста достаточно. При провале наружу отдаётся хвост serial-лога.
#
# usage: boot_smoke.sh <fuchsia-чекaут> [target] [timeout-сек]
set -uo pipefail

DIR="${1:?usage: boot_smoke.sh <fuchsia-чекaут> [target] [timeout-сек]}"
TARGET="${2:-bringup.x64}"
TIMEOUT="${3:-420}"
SERIAL_LOG="${SERIAL_LOG:-/tmp/femu-serial.log}"

# --- маркер загрузки ---
# bringup печатает собственное приветствие; для остальных продуктов ищем
# любые признаки старта user space (fshost, component_manager и т.д.).
MARKER="${MARKER:-}"
if [ -z "$MARKER" ]; then
  case "$TARGET" in
    bringup.*) MARKER='welcome to Zircon' ;;
    *) MARKER='welcome to Zircon|fshost|component_manager|console-launcher|driver_manager' ;;
  esac
fi

# --- fx ---
FX=""
for candidate in "$DIR/.jiri_root/bin/fx" "$DIR/scripts/fx"; do
  if [ -x "$candidate" ]; then
    FX="$candidate"
    break
  fi
done
[ -n "$FX" ] || { echo "boot_smoke: fx не найден в $DIR" >&2; exit 1; }

cd "$DIR" || exit 1

# --- образ (.zbi) ---
ZBI="$(find out -maxdepth 4 -name '*.zbi' -type f -size +1M -printf '%T@ %p\n' 2>/dev/null \
  | sort -rn | head -n1 | cut -d' ' -f2-)"
[ -n "$ZBI" ] || { echo "boot_smoke: .zbi не найден под out/" >&2; exit 1; }
case "$ZBI" in /*) ;; *) ZBI="$DIR/$ZBI" ;; esac
echo "[boot] target: $TARGET; образ: $ZBI; маркер: $MARKER"

FOUND=0
watch_emu() {
  # $@ — команда запуска эмулятора; serial-вывод уходит в SERIAL_LOG.
  : > "$SERIAL_LOG"
  "$@" >"$SERIAL_LOG" 2>&1 &
  local pid=$!
  for _ in $(seq 1 "$TIMEOUT"); do
    if grep -qE "$MARKER" "$SERIAL_LOG" 2>/dev/null; then
      FOUND=1
      break
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
      break
    fi
    sleep 1
  done
  kill "$pid" 2>/dev/null
  wait "$pid" 2>/dev/null
}

echo "[boot] попытка 1: fx emu --headless"
watch_emu "$FX" emu --headless

if [ "$FOUND" -ne 1 ]; then
  echo "[boot] попытка 2: прямой запуск эмулятора"
  FEMU_BIN="$(command -v femu 2>/dev/null || true)"
  if [ -z "$FEMU_BIN" ]; then
    FEMU_BIN="$(find "$DIR/prebuilt" -type f \( -name femu -o -name emulator \) 2>/dev/null | head -n1)"
  fi
  if [ -n "$FEMU_BIN" ] && [ -x "$FEMU_BIN" ]; then
    watch_emu "$FEMU_BIN" -m 4096 -nographic -monitor none \
      -kernel "$ZBI" -append "kernel.serial=legacy"
  else
    echo "[boot] бинарник эмулятора не найден — попытка пропущена"
  fi
fi

if [ "$FOUND" -eq 1 ]; then
  echo "[boot] OK: маркер загрузки найден"
  tail -n 20 "$SERIAL_LOG"
  exit 0
fi

echo "[boot] FAIL: маркер '$MARKER' не найден за ${TIMEOUT}s" >&2
tail -n 50 "$SERIAL_LOG" >&2
exit 1
