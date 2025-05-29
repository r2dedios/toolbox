#!/bin/bash
# This script removes a namespace stucked on "Terminating"

NAMESPACE=$1
[[ $NAMESPACE == "" ]] && { echo -e "[\033[31m❌\033[0m] Missing Namespace"; exit; }

echo -e "[\033[33m⚠️ \033[0m] The namespace '$NAMESPACE' is going to be deleted including every resource in it. Are you sure you want to proceed?"
read -n 1 -s -r -p "[Press any key to continue]"
echo

(
trap "kill 0" EXIT
kubectl proxy &
kubectl get namespace $NAMESPACE -o json |jq '.spec = {"finalizers":[]}' >temp.json
curl -k -H "Content-Type: application/json" -X PUT --data-binary @temp.json 127.0.0.1:8001/api/v1/namespaces/$NAMESPACE/finalize
rm temp.json
)

echo -e "[\033[32m✅\033[0m] Namespace '$NAMESPACE' removed"
