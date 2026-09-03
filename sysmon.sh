#!/usr/bin/env bash

set -u

readonly SLEEP=/usr/bin/sleep
readonly TIMEOUT=/usr/bin/timeout
readonly NVIDIA_SMI=/usr/bin/nvidia-smi

read_cpu() {
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  CPU_IDLE=$((idle + iowait))
  CPU_TOTAL=$((user + nice + system + idle + iowait + irq + softirq + steal))
}

read_network() {
  NET_RX=0
  NET_TX=0
  local iface state rx tx
  for iface in /sys/class/net/*; do
    [[ ${iface##*/} == lo ]] && continue
    state=$(<"$iface/operstate")
    [[ $state == up || $state == unknown ]] || continue
    rx=$(<"$iface/statistics/rx_bytes")
    tx=$(<"$iface/statistics/tx_bytes")
    NET_RX=$((NET_RX + rx))
    NET_TX=$((NET_TX + tx))
  done
}

cpu_temp() {
  local hwmon name input label zone type value
  for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -r $hwmon/name ]] || continue
    name=$(<"$hwmon/name")
    [[ $name == coretemp || $name == k10temp || $name == zenpower ]] || continue
    for input in "$hwmon"/temp*_input; do
      [[ -r $input ]] || continue
      label=${input%_input}_label
      if [[ -r $label ]]; then
        label=$(<"$label")
        [[ $label == "Package id 0" || $label == Tctl || $label == Tdie ]] || continue
      fi
      value=$(<"$input")
      printf '%d' "$((value / 1000))"
      return
    done
  done
  for zone in /sys/class/thermal/thermal_zone*; do
    [[ -r $zone/type && -r $zone/temp ]] || continue
    type=$(<"$zone/type")
    [[ $type == x86_pkg_temp || $type == TCPU ]] || continue
    value=$(<"$zone/temp")
    printf '%d' "$((value / 1000))"
    return
  done
  printf '%s' '-1'
}

gpu_stats() {
  local result first_line card busy temp input
  GPU_LOAD=-1
  GPU_TEMP=-1

  if [[ -x $NVIDIA_SMI && -x $TIMEOUT ]]; then
    result=$("$TIMEOUT" --kill-after=1s 2s "$NVIDIA_SMI" \
      --query-gpu=utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null) || result=''

    # Bound parsing to the first record and normalize spaces using Bash only.
    first_line=${result%%$'\n'*}
    first_line=${first_line// /}
    if [[ $first_line =~ ^([0-9]+),([0-9]+)$ ]]; then
      GPU_LOAD=${BASH_REMATCH[1]}
      GPU_TEMP=${BASH_REMATCH[2]}
      return
    fi
  fi

  for card in /sys/class/drm/card*; do
    [[ -r $card/device/gpu_busy_percent ]] || continue
    busy=$(<"$card/device/gpu_busy_percent")
    [[ $busy =~ ^[0-9]+$ ]] && GPU_LOAD=$busy
    for input in "$card"/device/hwmon/hwmon*/temp1_input; do
      [[ -r $input ]] || continue
      temp=$(<"$input")
      GPU_TEMP=$((temp / 1000))
      break
    done
    return
  done
}

read_cpu
previous_idle=$CPU_IDLE
previous_total=$CPU_TOTAL
read_network
previous_rx=$NET_RX
previous_tx=$NET_TX

while "$SLEEP" 2; do
  read_cpu
  total_delta=$((CPU_TOTAL - previous_total))
  idle_delta=$((CPU_IDLE - previous_idle))
  if ((total_delta > 0)); then
    cpu_load=$(((100 * (total_delta - idle_delta) + total_delta / 2) / total_delta))
  else
    cpu_load=0
  fi
  previous_idle=$CPU_IDLE
  previous_total=$CPU_TOTAL

  read_network
  rx_rate=$(((NET_RX - previous_rx) / 2))
  tx_rate=$(((NET_TX - previous_tx) / 2))
  ((rx_rate < 0)) && rx_rate=0
  ((tx_rate < 0)) && tx_rate=0
  previous_rx=$NET_RX
  previous_tx=$NET_TX

  cpu_temperature=$(cpu_temp)
  gpu_stats
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$cpu_load" "$cpu_temperature" "$GPU_LOAD" "$GPU_TEMP" "$rx_rate" "$tx_rate"
done
