#!/bin/bash
# This script lists every node on the cluster with statistics about its resources and usage

set -euo pipefail

for cmd in oc jq bc awk; do
  command -v "$cmd" &>/dev/null || { echo "Falta el comando '$cmd'."; exit 1; }
done

# Header
printf "%-30s %-25s %-15s %6s %6s %15s %15s %15s %15s %15s %15s %15s %10s %10s\n" \
  "NODE" "ROLES" "INSTANCE-TYPE" "PODS" \
	"CPU" "CPU_REQUESTED" "CPU_USED" "CPU_USED(%)" \
	"MEMORY(GB)" "MEM_REQUESTED" "MEM_USED" "MEM_USED(%)" \
  "GPUs" "GPU_REQS"
printf -- "%s\n" "$(printf '=%.0s' {1..230})"

# --- Arrays declaration ---
declare -A CPU_REQS MEM_REQS CPU_REAL MEM_REAL POD_COUNTS GPU_REQS

# --- CPU and Memory requested by node ---
while IFS=$'\t' read -r node cpu mem gpu; do
	# CPU sum
  [[ -z "${CPU_REQS[$node]+x}" ]] && { CPU_REQS["$node"]="$cpu" ; } || { CPU_REQS["$node"]=$(echo "${CPU_REQS[$node]} + $cpu" | bc -l ) ; }

	# Memory sum
  [[ -z "${MEM_REQS[$node]+x}" ]] && { MEM_REQS["$node"]="$mem" ; } || { MEM_REQS["$node"]=$(echo "${MEM_REQS[$node]} + $mem" | bc -l ) ; }

	# GPU sum
  [[ -z "${GPU_REQS[$node]+x}" ]] && { GPU_REQS["$node"]="$gpu" ; } || { GPU_REQS["$node"]=$(( ${GPU_REQS["$node"]} + "$gpu" )) ; }

done < <(
  oc get pods --all-namespaces -o json | jq -r '
    .items[] |
    select(.spec.nodeName != null) |
    {
      node: .spec.nodeName,
      cpu: (
        (.spec.containers // []) | map(
          (.resources.requests.cpu // "0") |
          if test("m$") then (sub("m$"; "") | tonumber / 1000)
          else tonumber end
        ) | add
      ),
      mem: (
        (.spec.containers // []) | map(
          (.resources.requests.memory // "0") |
          if test("Ki$") then (sub("Ki$"; "") | tonumber / 1024 / 1024)
          elif test("Mi$") then (sub("Mi$"; "") | tonumber / 1024)
          elif test("Gi$") then (sub("Gi$"; "") | tonumber)
          else 0 end
        ) | add
      ),
			gpu: (
        (.spec.containers // []) | map(
          (.resources.requests["nvidia.com/gpu"] // "0") | tonumber
        ) | add
      )
    } |
    [.node, (.cpu|tostring), (.mem|tostring), (.gpu|tostring)] | @tsv
')

# --- Pods counter by node ---
while IFS= read -r node; do
  if [[ -z "${POD_COUNTS[$node]+x}" ]]; then
		POD_COUNTS["$node"]=1
	else
		((POD_COUNTS["$node"]++))
	fi
done < <(oc get pods --all-namespaces -o json | jq -r '.items[] | select(.spec.nodeName != null) | .spec.nodeName')

# --- CPU/Memory usage by node ---
while read -r node cpu_used mem_used _; do
  CPU_REAL["$node"]=$(echo "$cpu_used" | sed 's/m//' | awk '{ printf "%.2f", $1 / 1000 }')
  unit=$(echo "$mem_used" | grep -o '[KMG]i')
  val=$(echo "$mem_used" | grep -o '^[0-9]\+')

  case "$unit" in
    Ki) MEM_REAL["$node"]=$(echo "$val / 1024 / 1024" | bc -l) ;;
    Mi) MEM_REAL["$node"]=$(echo "$val / 1024" | bc -l) ;;
    Gi) MEM_REAL["$node"]="$val" ;;
    *)  MEM_REAL["$node"]="0" ;;
  esac
done < <(oc adm top nodes --no-headers | awk '{ print $1, $2, $4 }')

# --- Get nodes data ---
oc get nodes -o json | jq -r '
	.items[] |
	{
		name: .metadata.name,
		cpu: (.status.capacity.cpu | tonumber),
		memKi: (.status.capacity.memory | sub("Ki$"; "") | tonumber),
		gpu: (.status.capacity["nvidia.com/gpu"] // "0"),
		labels: .metadata.labels
	} |
	{
		name: .name,
		cpu: .cpu,
		ramGB: (.memKi / 1024 / 1024 | floor),
		gpu: (if .gpu == "0" then "?" else .gpu end),
		roles: (
			[.labels | to_entries[] |
				select(.key | startswith("node-role.kubernetes.io/")) |
				.key | sub("node-role.kubernetes.io/"; "")
			] | join(",") | if . == "" then "?" else . end
		),
		instanceType: (
			.labels["node.kubernetes.io/instance-type"]
			// .labels["beta.kubernetes.io/instance-type"]
			// "?"
		)
	} |
	[.name, .roles, (.cpu|tostring), (.ramGB|tostring), .gpu, .instanceType] | @tsv
' | while IFS=$'\t' read -r NODE ROLES CPU RAM_GB GPU INSTANCE; do
  CPU_REQ=$(printf '%.3f' "${CPU_REQS[$NODE]:-0}")
  MEM_REQ=$(printf '%.3f' "${MEM_REQS[$NODE]:-0}")
  CPU_USED_PCT=$(echo "scale=2; 100 * $CPU_REQ / $CPU" | bc)
  MEM_USED_PCT=$(echo "scale=2; 100 * $MEM_REQ / $RAM_GB" | bc)
	GPU_REQS_COUNT=${GPU_REQS[$NODE]:-0}

  POD_COUNT="${POD_COUNTS[$NODE]:-0}"
  CPU_USED_REAL=$(printf '%.3f' "${CPU_REAL[$NODE]:-0.00}")
  MEM_USED_REAL=$(printf '%.3f' "${MEM_REAL[$NODE]:-0.00}")

  printf "%-30s %-25s %-15s %6s %6s %15s %15s %15s %15s %15s %15s %15s %10s %10s\n" \
    "$NODE" "$ROLES" "$INSTANCE" "$POD_COUNT" \
		"$CPU" "$CPU_REQ" "$CPU_USED_REAL" "${CPU_USED_PCT}%" \
		"$RAM_GB" "$MEM_REQ" "$MEM_USED_REAL" "${MEM_USED_PCT}%" \
		"$GPU" "$GPU_REQS_COUNT"
done
