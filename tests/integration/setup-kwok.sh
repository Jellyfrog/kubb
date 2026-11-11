#!/usr/bin/env bash
# Creates the kwok clusters used by the integration tests and adds them to
# ~/.kube/config. Requires kwokctl, kubectl and yq. Set KWOK_RUNTIME=binary to run
# without docker.
#
#   kwok-production      admin access, 3 nodes, namespaces app-1, app-2 and
#                        monitoring, a deployment in app-2
#   kwok-staging         admin access, no extra resources
#   kwok-production-dev  same cluster, impersonating user "dev" who may only
#                        read in app-2 and cannot list namespaces
set -euo pipefail

kwokctl create cluster --name=production
kwokctl create cluster --name=staging
kwokctl scale node --replicas=3 --name=production

k() { kubectl --context kwok-production "$@"; }

for ns in app-1 app-2 monitoring; do
  k create namespace "${ns}"
done
k -n app-2 create deployment my-deployment --image=pod --replicas=2

k -n app-2 create rolebinding dev-view --clusterrole=view --user=dev

# Context that authenticates as admin but impersonates "dev"
kubectl config set-credentials kwok-production-dev \
  --client-certificate="$(kubectl config view -o jsonpath='{.users[?(@.name=="kwok-production")].user.client-certificate}')" \
  --client-key="$(kubectl config view -o jsonpath='{.users[?(@.name=="kwok-production")].user.client-key}')"
yq -i '(.users[] | select(.name == "kwok-production-dev") | .user.as) = "dev"' \
  "${KUBECONFIG:-${HOME}/.kube/config}"
kubectl config set-context kwok-production-dev \
  --cluster=kwok-production --user=kwok-production-dev --namespace=app-2

# Sanity checks
k -n app-2 wait --for=condition=Available deployment/my-deployment --timeout=120s
if kubectl --context kwok-production-dev get namespaces >/dev/null 2>&1; then
  echo "dev user can unexpectedly list namespaces" >&2
  exit 1
fi
kubectl --context kwok-production-dev -n app-2 get pods >/dev/null
