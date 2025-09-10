Update script for Raspberry Pi OS

This folder contains a small shell script to update Raspberry Pi OS safely.

Files:

- `update-raspios.sh` - non-interactive updater. Supports options:
  - `-y` auto-yes
  - `-n` dry-run
  - `-r` reboot after update
  - `-h` help

Example usage:

Run interactively (you'll be prompted by apt when appropriate):

```bash
sudo ./update-raspios.sh
```

Run non-interactively and reboot after success:

```bash
sudo ./update-raspios.sh -y -r
```

Dry-run to preview actions:

```bash
./update-raspios.sh -n
```
