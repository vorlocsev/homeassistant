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
