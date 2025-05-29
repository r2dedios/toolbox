#!/bin/bash
# This script displays node usage graphically

function print_bar() {
  local value=$1
  local max=50
  local units=$((value * max / 100))
  for ((i = 0; i < units; i++)); do printf "█"; done
  for ((i = units; i < max; i++)); do printf "░"; done
}

function parse_quantity() {
  local qty="$1"
  if [[ "$qty" == *"m" ]]; then
    echo "${qty%m}"
  elif [[ "$qty" == *"Ki" ]]; then
    echo $(( ${qty%Ki} / 1024 ))
  elif [[ "$qty" == *"Mi" ]]; then
    echo "${qty%Mi}"
  elif [[ "$qty" == *"Gi" ]]; then
    echo $(( ${qty%Gi} * 1024 ))
  else
    echo "$qty"
  fi
}

printf "%-20s | %-12s | %-12s | %-12s | %-12s | %-10s\n" "NODE" "CPU(%)" "REQ_CPU(%)" "MEM(Mi)" "REQ_MEM(Mi)" "OVER?"

nodes=$(oc get nodes -o json)

for node in $(echo "$nodes" | jq -r '.items[].metadata.name'); do
  allocatable=$(oc get node "$node" -o json)
  total_cpu=$(parse_quantity "$(echo "$allocatable" | jq -r '.status.allocatable.cpu')")
  total_mem=$(parse_quantity "$(echo "$allocatable" | jq -r '.status.allocatable.memory')")
  reqs=$(oc adm top node "$node" --no-headers)

  used_cpu=$(echo "$reqs" | awk '{print $2}' | sed 's/m//')
  used_mem=$(echo "$reqs" | awk '{print $4}')
  used_mem_mi=$(parse_quantity "$used_mem")

  # Percentage calculation
  cpu_pct=$(( 100 * used_cpu / total_cpu ))
  mem_pct=$(( 100 * used_mem_mi / total_mem ))

  # Overcommit if requests > 100%
  over_cpu="NO"
  over_mem="NO"
  if (( cpu_pct > 100 )); then over_cpu="YES"; fi
  if (( mem_pct > 100 )); then over_mem="YES"; fi
  over="${over_cpu}/${over_mem}"

  printf "%-20s | " "$node"
  print_bar "$cpu_pct"; printf " %3d%% | " "$cpu_pct"
  print_bar "$mem_pct"; printf " %3d%% | " "$mem_pct"
  printf "%10s | %10s | %s\n" "$total_mem" "$used_mem_mi" "$over"
done
