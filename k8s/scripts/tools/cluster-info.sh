#!/bin/bash
set -euo pipefail

# Check for required tools
for cmd in oc jq; do
  command -v "$cmd" &>/dev/null || { echo "Missing required command '$cmd'."; exit 1; }
done

echo "================== OpenShift Cluster Summary =================="

# Cluster name
CLUSTER_NAME=$(oc get infrastructure cluster -o jsonpath='{.metadata.name}')
printf "%-30s : %s\n" "Cluster Name" "$CLUSTER_NAME"

# Cluster version and update channel
CLUSTER_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}')
UPDATE_CHANNEL=$(oc get clusterversion version -o jsonpath='{.spec.channel}')
printf "%-30s : %s\n" "Cluster Version" "$CLUSTER_VERSION"
printf "%-30s : %s\n" "Update Channel" "$UPDATE_CHANNEL"

# Check if updates are available
UPDATES_AVAILABLE=$(oc get clusterversion version -o json | jq -r '.status.availableUpdates | length')
if [[ "$UPDATES_AVAILABLE" -gt 0 ]]; then
  UPDATE_STATUS="Yes ($UPDATES_AVAILABLE available)"
else
  UPDATE_STATUS="No"
fi
printf "%-30s : %s\n" "Updates Available" "$UPDATE_STATUS"

# OCM subscription link (clusterID)
CLUSTER_ID=$(oc get clusterversion version -o jsonpath='{.spec.clusterID}')
OCM_URL="https://console.redhat.com/openshift/details/s/${CLUSTER_ID}"
printf "%-30s : %s\n" "OCM Subscription URL" "$OCM_URL"

# API server URL
API_URL=$(oc whoami --show-server)
printf "%-30s : %s\n" "API Server URL" "$API_URL"

# Web Console URL
CONSOLE_URL=$(oc get route console -n openshift-console -o jsonpath='https://{.spec.host}')
printf "%-30s : %s\n" "Web Console URL" "$CONSOLE_URL"

# Base domain
BASE_DOMAIN=$(oc get dns cluster -o jsonpath='{.spec.baseDomain}')
printf "%-30s : %s\n" "Base Domain" "$BASE_DOMAIN"

# Node roles
MASTER_NODES=$(oc get nodes -l node-role.kubernetes.io/master -o name | wc -l)
WORKER_NODES=$(oc get nodes -l node-role.kubernetes.io/worker -o name | wc -l)
INFRA_NODES=$(oc get nodes -l node-role.kubernetes.io/infra -o name | wc -l)
TOTAL_NODES=$(oc get nodes --no-headers | wc -l)
NODE_DETAIL="Master: $MASTER_NODES, Worker: $WORKER_NODES, Infra: $INFRA_NODES"
printf "%-30s : %s (%s)\n" "Total Nodes" "$TOTAL_NODES" "$NODE_DETAIL"

# Cluster Operators status
CO_READY=$(oc get co -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Available" and .status=="True"))] | length')
CO_NOT_READY=$(oc get co -o json | jq '[.items[] | select(.status.conditions[] | select(.type=="Available" and .status!="True"))] | length')
printf "%-30s : %s Ready / %s NotReady\n" "Cluster Operators" "$CO_READY" "$CO_NOT_READY"

# Cluster UID (serial number)
CLUSTER_UID=$(oc get clusterversion version -o jsonpath='{.metadata.uid}')
printf "%-30s : %s\n" "Cluster UID" "$CLUSTER_UID"

# Infrastructure provider
PROVIDER=$(oc get infrastructure cluster -o jsonpath='{.status.platform}')
printf "%-30s : %s\n" "Infrastructure Provider" "$PROVIDER"

# Extract region(s) from node labels
REGIONS=$(oc get nodes -o jsonpath='{range .items[*]}{.metadata.labels.topology\.kubernetes\.io/region}{"\n"}{end}' | sort -u | paste -sd "," -)
if [[ -z "$REGIONS" || "$REGIONS" == "," ]]; then
  # Fallback to legacy label if needed
  REGIONS=$(oc get nodes -o jsonpath='{range .items[*]}{.metadata.labels.failure-domain\.beta\.kubernetes\.io/region}{"\n"}{end}' | sort -u | paste -sd "," -)
fi
[[ -z "$REGIONS" ]] && REGIONS="Unknown"

printf "%-30s : %s\n" "Cluster Region(s)" "$REGIONS"

# Number of namespaces
NS_COUNT=$(oc get ns --no-headers | wc -l)
printf "%-30s : %s\n" "Total Namespaces" "$NS_COUNT"

# Pods in error state
PODS_BAD=$(oc get pods --all-namespaces --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers | wc -l)
printf "%-30s : %s\n" "Pods in Error State" "$PODS_BAD"

echo "==============================================================="
