#!/bin/sh
# Aurora Home: safely upgrade an existing dashboard with dynamic entity discovery.
# Only /config/aurora_home.yaml is replaced, after a backup and config checks.
set -eu

CONFIG_DIR="${AURORA_CONFIG_DIR:-/config}"
TARGET="$CONFIG_DIR/aurora_home.yaml"
BASE_URL="${AURORA_BASE_URL:-https://raw.githubusercontent.com/vorlocsev/homeassistant/master/aurora-home}"

say() { printf '%s\n' "$*"; }
fail() { say "ОШИБКА: $*" >&2; exit 1; }

[ -f "$TARGET" ] || fail "Aurora Home не найдена: $TARGET"
grep -q '^title: Aurora Home' "$TARGET" || fail "Этот файл не похож на Aurora Home; не перезаписываю."
command -v ha >/dev/null 2>&1 || fail "Не найден Home Assistant CLI."
command -v mktemp >/dev/null 2>&1 || fail "Не найден mktemp."

# The live entity catalog relies on the open-source auto-entities Lovelace card.
# Require the actual JS asset, not only a possibly stale resources declaration.
HAS_AUTO=0
for file in \
  "$CONFIG_DIR/www/community/lovelace-auto-entities/auto-entities.js" \
  "$CONFIG_DIR/www/community/auto-entities/auto-entities.js" \
  "$CONFIG_DIR/www/lovelace-auto-entities/auto-entities.js"
do
  [ -s "$file" ] && HAS_AUTO=1
done
if [ "$HAS_AUTO" = 0 ] && [ -d "$CONFIG_DIR/www" ]; then
  if find "$CONFIG_DIR/www" -type f -name 'auto-entities.js' -print -quit | grep -q .; then
    HAS_AUTO=1
  fi
fi
[ "$HAS_AUTO" = 1 ] || fail "Не найдена карточка auto-entities. Установи 'auto-entities' через HACS → Frontend и повтори команду."
if ! grep -q 'auto-entities.js' "$CONFIG_DIR/configuration.yaml" && \
   ! { [ -f "$CONFIG_DIR/.storage/lovelace_resources" ] && grep -q 'auto-entities.js' "$CONFIG_DIR/.storage/lovelace_resources"; }; then
  fail "Не найдена регистрация auto-entities в Lovelace resources. Подключи карточку через HACS / Настройки → Панели → Ресурсы."
fi

TMPDIR="$(mktemp -d "$CONFIG_DIR/.aurora-upgrade.XXXXXX")"
BACKUP=""
OK=0
cleanup() {
  rc=$?
  trap - EXIT HUP INT TERM
  if [ "$OK" = 0 ] && [ -n "$BACKUP" ] && [ -f "$BACKUP" ]; then
    say "Восстанавливаю прежнюю панель..." >&2
    cp -p "$BACKUP" "$TARGET" || true
  fi
  rm -rf "$TMPDIR"
  exit "$rc"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

say "Проверяю конфигурацию до изменений..."
if ! ha core check > "$TMPDIR/check-before.log" 2>&1; then
  tail -n 20 "$TMPDIR/check-before.log" >&2
  fail "Исходная конфигурация содержит ошибки; обновление отменено."
fi

URL_FILE="aurora_dashboard_extended_no_theme.yaml"
if [ -f "$CONFIG_DIR/themes/aurora_home.yaml" ] && grep -q '^Aurora Home:' "$CONFIG_DIR/themes/aurora_home.yaml"; then
  URL_FILE="aurora_dashboard_extended.yaml"
fi

say "Скачиваю расширенную панель Aurora Home..."
if command -v curl >/dev/null 2>&1; then
  curl -fsSL --max-time 50 "$BASE_URL/$URL_FILE" -o "$TMPDIR/dashboard.yaml"
elif command -v wget >/dev/null 2>&1; then
  wget -q -T 50 -O "$TMPDIR/dashboard.yaml" "$BASE_URL/$URL_FILE"
else
  fail "Необходим curl или wget."
fi
[ -s "$TMPDIR/dashboard.yaml" ] || fail "Загружен пустой файл."
grep -q '^title: Aurora Home' "$TMPDIR/dashboard.yaml" || fail "Некорректный заголовок YAML."
for page in '    path: control' '    path: sensors' '    path: catalog'; do
  grep -Fq "$page" "$TMPDIR/dashboard.yaml" || fail "В YAML отсутствует раздел: $page"
done
grep -q 'type: custom:auto-entities' "$TMPDIR/dashboard.yaml" || fail "В файле нет автокаталога."

BACKUP_DIR="$CONFIG_DIR/.aurora-home-backups/$(date +%Y%m%d-%H%M%S)-$$"
mkdir -p "$BACKUP_DIR"
BACKUP="$BACKUP_DIR/aurora_home.yaml"
cp -p "$TARGET" "$BACKUP"

# Rename within /config for an atomic replacement.
cp "$TMPDIR/dashboard.yaml" "$TMPDIR/new-dashboard.yaml"
chmod 644 "$TMPDIR/new-dashboard.yaml"
mv -f "$TMPDIR/new-dashboard.yaml" "$TARGET"

say "Проверяю конфигурацию после обновления..."
if ! ha core check > "$TMPDIR/check-after.log" 2>&1; then
  tail -n 25 "$TMPDIR/check-after.log" >&2
  fail "Проверка не пройдена; предыдущая Aurora будет восстановлена."
fi

OK=1
say "ГОТОВО: добавлены Управление, Датчики и Все сущности."
say "Резервная копия: $BACKUP"
say "Обнови страницу Aurora Home в браузере."
say "Каталог: http://homeassistant.local:8123/aurora-home/catalog"
say "Core не перезапускался, другие панели и настройки не изменялись."
