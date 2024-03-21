#!/bin/sh
set -e

function usage() {
  echo "Usage: $(basename $0) [-s <subscription>] -g <resource_group_name> -c <cluster_name> -n <namespace>"
  echo "Example: $(basename $0) -g my-rg -c my-aks-cluster -n my-namespace"
  exit 1
}

while getopts ':g:c:n:s:' option; do
  case "${option}" in
    s) subscription=${OPTARG};;
    g) resourceGroup=${OPTARG};;
    c) clusterName=${OPTARG};;
    n) namespace=${OPTARG};;
    ?) usage;;
  esac
done

echo "Resource group: $resourceGroup"
echo "Cluster name: $clusterName"
echo "Namespace: $namespace"

if [[ -z $resourceGroup ]] || [[ -z $clusterName ]] || [[ -z $namespace ]]; then
  usage
fi

if [[ -n $subscription ]]; then
  echo "Subscription: $subscription"
  subscriptionOption=$(echo "--subscription $subscription")
fi

serviceAccount="ado-sc-sa"
serviceAccountRole="ado-sc-sa-role"
serviceAccountRoleBinding="ado-sc-sa-rolebinding"
serviceAccountSecret="ado-sc-sa-secret"

echo "Connectiong to AKS cluster..."
az aks get-credentials --resource-group $resourceGroup --name $clusterName $subscriptionOption

echo "Creating service account..."
kubectl apply -f -<<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
   name: $serviceAccount
   namespace: $namespace  
EOF

echo "Creating role..."
kubectl apply -f -<<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: $serviceAccountRole
  namespace: $namespace
rules:
- apiGroups: ["*","apps","extensions"]
  resources: ["*"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
EOF

echo "Creating role binding..."
kubectl apply -f -<<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: $serviceAccountRoleBinding
  namespace: $namespace
subjects:
- kind: ServiceAccount
  name: $serviceAccount
  namespace: $namespace
roleRef:
  kind: Role
  name: $serviceAccountRole
  apiGroup: rbac.authorization.k8s.io
EOF

echo "Creating secret..."
kubectl apply -f -<<EOF
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: $serviceAccountSecret
  namespace: $namespace
  annotations:
    kubernetes.io/service-account.name: "$serviceAccount"
EOF

echo
echo "Service account created. Please use following information to create service connection in Azure DevOps:"
echo 
echo "Cluster name: $(kubectl config view --minify -o jsonpath='{.clusters[0].name}')"
echo "Cluster URL: $(kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')"
echo "Secret content:"
kubectl get secret ado-sc-sa-secret -n $namespace -o json