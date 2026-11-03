#!/bin/sh
# Aurora Home dashboard installer for Home Assistant OS / Terminal & SSH.
# Installs a separate YAML dashboard; never replaces the default Overview.
set -eu

CONFIG_DIR="${AURORA_CONFIG_DIR:-/config}"
CONFIG_FILE="$CONFIG_DIR/configuration.yaml"
BASE_URL="${AURORA_BASE_URL:-https://raw.githubusercontent.com/vorlocsev/homeassistant/master/aurora-home}"
DASH_FILE="$CONFIG_DIR/aurora_home.yaml"
THEME_FILE="$CONFIG_DIR/themes/aurora_home.yaml"

say() { printf '%s\n' "$*"; }
fail() { say "ОШИБКА: $*" >&2; exit 1; }

[ -f "$CONFIG_FILE" ] || fail "Файл $CONFIG_FILE не найден. Запускай через Terminal & SSH в Home Assistant OS."
command -v awk >/dev/null 2>&1 || fail "Не найдена утилита awk."
command -v ha >/dev/null 2>&1 || fail "Не найден Home Assistant CLI (ha)."

# Do not modify configuration.yaml if it was already invalid before Aurora.
# This distinguishes pre-existing YAML errors from installer-generated errors.
say "Проверяю исходную конфигурацию Home Assistant до изменений..."
BASELINE_LOG="$(mktemp)"
if ! ha core check > "$BASELINE_LOG" 2>&1; then
  tail -n 32 "$BASELINE_LOG" >&2
  rm -f "$BASELINE_LOG"
  fail "Исходная конфигурация уже содержит ошибку. Никаких изменений не выполнено. Исправь её до установки Aurora."
fi
rm -f "$BASELINE_LOG"
say "Исходная конфигурация прошла проверку."
if [ -f "$DASH_FILE" ]; then
  say "Aurora Home уже существует: $DASH_FILE"
  say "Для защиты твоих изменений повторный запуск не перезаписывает панель."
  exit 0
fi

if grep -Eq '^lovelace:[[:space:]]*![^[:space:]]+' "$CONFIG_FILE"; then
  fail "Блок lovelace подключён через !include: автоматическая правка небезопасна. Используй ручной пакет."
fi
if grep -Eq '^    aurora-home:[[:space:]]*($|#)' "$CONFIG_FILE"; then
  fail "Ключ aurora-home уже существует. Не буду его перезаписывать."
fi
if grep -Eq '^lovelace:[[:space:]]*[^[:space:]#]' "$CONFIG_FILE" && \
   ! grep -Eq '^lovelace:[[:space:]]*($|#)' "$CONFIG_FILE"; then
  fail "Неожиданная форма блока lovelace; файл конфигурации оставлен без изменений."
fi

TMP="$(mktemp -d "$CONFIG_DIR/.aurora-home-tmp.XXXXXX")" || fail "Невозможно создать временный каталог."
DONE=0
BACKUP_DIR=""
DID_THEME=0
DID_DASH=0
cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  if [ "$DONE" != 1 ] && [ -n "$BACKUP_DIR" ]; then
    say "Возвращаю исходную конфигурацию после ошибки..." >&2
    cp "$BACKUP_DIR/configuration.yaml" "$CONFIG_FILE" 2>/dev/null || true
    [ "$DID_DASH" = 1 ] && rm -f "$DASH_FILE"
    [ "$DID_THEME" = 1 ] && rm -f "$THEME_FILE"
  fi
  rm -rf "$TMP"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

fetch() {
  remote="$1"
  dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl --fail --silent --show-error --location --max-time 40 "$remote" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -T 40 -O "$dest" "$remote"
  else
    fail "Нужен curl или wget для загрузки файлов."
  fi
  [ -s "$dest" ] || fail "Загрузка $remote завершилась пустым файлом."
}

say "Aurora Home: загрузка панели и оформления..."
fetch "$BASE_URL/aurora_dashboard.yaml" "$TMP/aurora_dashboard.yaml"
fetch "$BASE_URL/aurora_dashboard_no_theme.yaml" "$TMP/aurora_dashboard_no_theme.yaml"
fetch "$BASE_URL/aurora_home_theme.yaml" "$TMP/aurora_home_theme.yaml"
grep -q '^views:' "$TMP/aurora_dashboard.yaml" || fail "Получена некорректная панель."
grep -q '^Aurora Home:' "$TMP/aurora_home_theme.yaml" || fail "Получена некорректная тема."

USE_THEME=1
if grep -Eq '^frontend:[[:space:]]*![^[:space:]]+' "$CONFIG_FILE"; then
  USE_THEME=0
  say "Тема не подключается: frontend определён через !include. Панель всё равно будет установлена."
elif grep -Eq '^  themes:[[:space:]]*' "$CONFIG_FILE"; then
  if ! grep -Eq '^  themes:[[:space:]]*!include_dir_merge_named[[:space:]]+themes([[:space:]]|$)' "$CONFIG_FILE"; then
    USE_THEME=0
    say "Тема не подключается: найдено нестандартное объявление frontend.themes."
  fi
fi

BACKUP_DIR="$CONFIG_DIR/.aurora-home-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP_DIR"
cp -p "$CONFIG_FILE" "$BACKUP_DIR/configuration.yaml"

if [ "$USE_THEME" = 1 ] && ! grep -Eq '^  themes:[[:space:]]*' "$CONFIG_FILE"; then
  if grep -Eq '^frontend:[[:space:]]*($|#)' "$CONFIG_FILE"; then
    awk '
      function inject() { print "  themes: !include_dir_merge_named themes" }
      /^frontend:[[:space:]]*($|#)/ { inside=1; print; next }
      inside && /^[^[:space:]#]/ { inject(); inside=0 }
      { print }
      END { if (inside) inject() }
    ' "$CONFIG_FILE" > "$TMP/config.tmp"
    cp "$TMP/config.tmp" "$CONFIG_FILE"
  else
    printf '\nfrontend:\n  themes: !include_dir_merge_named themes\n' >> "$CONFIG_FILE"
  fi
fi

if grep -Eq '^lovelace:[[:space:]]*($|#)' "$CONFIG_FILE"; then
  if grep -Eq '^  dashboards:[[:space:]]*($|#)' "$CONFIG_FILE"; then
    awk '
      function add_panel() {
        print "    aurora-home:"
        print "      mode: yaml"
        print "      filename: aurora_home.yaml"
        print "      title: Aurora Home"
        print "      icon: mdi:home-variant-outline"
        print "      show_in_sidebar: true"
      }
      /^lovelace:[[:space:]]*($|#)/ { lov=1; print; next }
      lov && /^  dashboards:[[:space:]]*($|#)/ { dash=1; print; next }
      dash && (/^[^[:space:]#]/ || /^  [^[:space:]#]/) { add_panel(); dash=0 }
      { print }
      END { if (dash) add_panel() }
    ' "$CONFIG_FILE" > "$TMP/config.tmp"
    cp "$TMP/config.tmp" "$CONFIG_FILE"
  else
    awk '
      function add_panel() {
        print "  dashboards:"
        print "    aurora-home:"
        print "      mode: yaml"
        print "      filename: aurora_home.yaml"
        print "      title: Aurora Home"
        print "      icon: mdi:home-variant-outline"
        print "      show_in_sidebar: true"
      }
      /^lovelace:[[:space:]]*($|#)/ { lov=1; print; next }
      lov && /^[^[:space:]#]/ { add_panel(); lov=0 }
      { print }
      END { if (lov) add_panel() }
    ' "$CONFIG_FILE" > "$TMP/config.tmp"
    cp "$TMP/config.tmp" "$CONFIG_FILE"
  fi
else
  cat >> "$CONFIG_FILE" <<'EOF'

lovelace:
  dashboards:
    aurora-home:
      mode: yaml
      filename: aurora_home.yaml
      title: Aurora Home
      icon: mdi:home-variant-outline
      show_in_sidebar: true
EOF
fi

if [ "$USE_THEME" = 1 ]; then
  mkdir -p "$CONFIG_DIR/themes"
  if [ -f "$THEME_FILE" ]; then
    say "Существующая тема aurora_home.yaml сохранена: использую вариант без темы."
    USE_THEME=0
  else
    cp "$TMP/aurora_home_theme.yaml" "$THEME_FILE"
    DID_THEME=1
  fi
fi

if [ "$USE_THEME" = 1 ]; then
  cp "$TMP/aurora_dashboard.yaml" "$DASH_FILE"
else
  cp "$TMP/aurora_dashboard_no_theme.yaml" "$DASH_FILE"
fi
DID_DASH=1

say "Проверяю конфигурацию Home Assistant..."
if ! ha core check > "$TMP/check.log" 2>&1; then
  tail -n 35 "$TMP/check.log" >&2
  fail "Проверка не пройдена, установщик вернёт старую конфигурацию."
fi
DONE=1
say "Готово: новая панель добавлена. Резервная копия: $BACKUP_DIR"
say "Тема: $([ "$USE_THEME" = 1 ] && printf 'Aurora Home' || printf 'стандартная')"

if [ "${AURORA_NO_RESTART:-0}" = 1 ]; then
  say "Перезапуск пропущен (AURORA_NO_RESTART=1)."
else
  say "Перезапускаю Home Assistant Core для регистрации панели..."
  if ! ha core restart; then
    say "ПРЕДУПРЕЖДЕНИЕ: перезапуск не подтверждён. Сделай его через Настройки → Система."
  fi
fi
say "Открыть: http://homeassistant.local:8123/aurora-home/home"
