#!/bin/bash
# This script looks for RoleBindings and ClusterRoleBindings for a specific subject

SA=$1
[[ $SA == "" ]] && { echo -e "[\033[31m❌\033[0m] Missing Service Account"; exit; }

# Rolebindings search
(
echo -e "[\033[33m⚠️ \033[0m] Looking for RoleBindings for subject: '$SA'"
echo "[KIND, NAME, NAMESPACE, RoleRef.Kind, RoleRef.Name]"
kubectl get rolebinding --all-namespaces -o json | jq -r --arg SA "$SA" '
  .items[] |
  select(.subjects[]?.name == $SA) |
  [.kind, .metadata.name, .metadata.namespace, .roleRef.kind, .roleRef.name] | @csv
'
) | more

# ClusterRoleBindings search
(
echo -e "[\033[33m⚠️ \033[0m] Looking for ClusterRoleBindings for subject: '$SA'"
kubectl get clusterrolebinding -o json | jq -r --arg SA "$SA" '
  .items[] |
  select(.subjects[]?.name == $SA) |
  [.kind, .metadata.name, .roleRef.kind, .roleRef.name] | @csv
'
) | more
