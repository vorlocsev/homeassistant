# Aurora Home for Home Assistant

Responsive dashboard (Home Assistant 2026.10+) using only built-in Lovelace cards. Five pages: Главная, Музыка, Katana, Сервер, Устройства.

## One-command install in Terminal & SSH

```sh
wget -qO /tmp/aurora-home-install.sh https://raw.githubusercontent.com/vorlocsev/homeassistant/master/aurora-home/install.sh && sh /tmp/aurora-home-install.sh
```

After Home Assistant Core restarts, open **Aurora Home** in the sidebar or go to:

http://homeassistant.local:8123/aurora-home/home

### Safety

- Creates a **separate** YAML dashboard; does not replace Overview or touch automations, MQTT, Recorder, or Zigbee.
- Copies `configuration.yaml` to `/config/.aurora-home-backups/` before modification.
- Installs the Aurora theme when the current frontend theme configuration allows it; otherwise uses a no-theme variant.
- Runs `ha core check` and **rolls back** changes if the check fails.
- Restarts only Home Assistant Core after successful verification.
- Refuses to modify an external Lovelace include; refuses to overwrite an existing Aurora Home file.

The script is intended for official Home Assistant OS **Terminal & SSH** and relies on built-in `ha`, `awk`, `wget` or `curl`. Review [install.sh](install.sh) before running; use the downloaded ZIP for manual installation if preferred.

**Note:** This is a one-command installer, not a remotely executed one-click Home Assistant add-on. It has not been executed against the live Home Assistant host from this conversation.

## Обновление существующей Aurora Home: все сущности

Содержит три новых вкладки: **Управление**, **Датчики**, **Все сущности**. Динамические списки отображают все доступные сущности по их типам, а полный каталог перечисляет все сущности, имеющие текущее состояние. Сущности, отключённые в реестре и не имеющие состояния, по определению не показываются.

Нужна HACS Lovelace-карточка [auto-entities](https://github.com/thomasloven/lovelace-auto-entities), с зарегистрированным JS-ресурсом. Обновлятор проверяет её наличие и не изменяет панель, если карточка отсутствует.

```sh
wget -qO /tmp/aurora-upgrade.sh https://raw.githubusercontent.com/vorlocsev/homeassistant/master/aurora-home/upgrade-entities.sh && sh /tmp/aurora-upgrade.sh
```

Обновлятор проверяет первоначальную конфигурацию, создаёт резервную копию текущей `/config/aurora_home.yaml` в `/config/.aurora-home-backups/`, заменяет **только** файл Aurora, выполняет `ha core check` и восстанавливает предыдущее содержимое при ошибке. Он **не перезапускает Core**, не меняет `configuration.yaml` и не удаляет другие панели. Если Aurora была вручную изменена, твои правки остаются в резервной копии.

Новая страница: `/aurora-home/catalog`. Из-за большого количества сущностей она может загружаться дольше; остальные страницы разбиты по категориям.

**Внимание:** если репозиторий станет приватным, публичные raw-ссылки `raw.githubusercontent.com` больше не будут доступны без авторизации. Для приватной установки скачай содержимое репозитория через GitHub и используй локальные файлы.
