# Omarchy SysMon

A lightweight Omarchy bar widget showing live:

- CPU usage and package temperature
- GPU usage and temperature
- Download and upload speeds

Readings update every two seconds. Unsupported sensors display `--` without breaking the widget.

## Requirements

- Omarchy 4 or newer
- Bash
- Linux `/proc` and `/sys` metrics
- Optional: `nvidia-smi` for NVIDIA GPU readings

CPU temperature supports common Intel and AMD hwmon sensors. GPU monitoring uses NVIDIA's management interface first and falls back to DRM sysfs counters when available. Network speed aggregates active non-loopback interfaces.

## Install

```bash
omarchy plugin add https://github.com/chrisu2/omarchy-sysmon --enable --yes
```

If Omarchy does not choose a placement automatically:

```bash
omarchy plugin enable chris.sysmon right
```

## License

MIT
