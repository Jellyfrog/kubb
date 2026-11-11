#!/usr/bin/env bats
# Integration tests against live kwok clusters; only fzf is stubbed.
#
#   tests/integration/setup-kwok.sh                       # once
#   bats tests/integration/                               # bash
#   KUBB_TEST_SHELL=zsh bats tests/integration/           # zsh

load ../test_helper

setup() {
  kubb_test_setup live
  for ctx in kwok-production kwok-staging kwok-production-dev; do
    kubectl config get-contexts "${ctx}" >/dev/null 2>&1 \
      || skip "context ${ctx} missing, run tests/integration/setup-kwok.sh"
  done
  KUBECONFIG_FILE="${HOME}/.kube/config"
}

ctx() {
  export KUBB_TEST_FZF_OUTPUT="${KUBECONFIG_FILE} $1"
}

# --- contexts ----------------------------------------------------------------

@test "ctx lists the kwok contexts" {
  ctx kwok-production
  run kubb_session 'kubb ctx'
  grep -qxF "${KUBECONFIG_FILE} kwok-production" "${KUBB_TEST_LOG}/fzf.input"
  grep -qxF "${KUBECONFIG_FILE} kwok-staging" "${KUBB_TEST_LOG}/fzf.input"
  grep -qxF "${KUBECONFIG_FILE} kwok-production-dev" "${KUBB_TEST_LOG}/fzf.input"
}

@test "ctx switches to the cluster" {
  ctx kwok-production
  run kubb_session 'kubb ctx; kubectl get nodes --no-headers'
  [ "$status" -eq 0 ]
  [ "$(state CURRENT_CONTEXT)" = "kwok-production" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "default" ]
  [ "$(grep -c ' Ready ' <<<"$output")" -eq 3 ]
}

@test "ctx switches between clusters" {
  ctx kwok-production
  run kubb_session 'kubb ctx
                    export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/config kwok-staging"
                    kubb ctx
                    kubectl get nodes --no-headers | wc -l'
  [ "$(state CURRENT_CONTEXT)" = "kwok-staging" ]
  [ "${lines[-1]// /}" = "0" ]
}

@test "ctx does not change the context of the original kubeconfig" {
  before="$(kubectl config current-context)"
  ctx kwok-production-dev
  run kubb_session 'kubb ctx; kubb ns app-1'
  [ "$(kubectl config current-context)" = "${before}" ]
  [ -z "$(kubectl config view -o jsonpath='{.contexts[?(@.name=="kwok-production")].context.namespace}')" ]
}

@test "ctx preview shows the cluster's nodes" {
  ctx kwok-production
  run kubb_session 'kubb ctx; fzf_preview "${HOME}/.kube/config" kwok-production'
  [ "$status" -eq 0 ]
  plain="$(sed 's/\x1b\[[0-9;]*m//g' <<<"$output")"   # yq colors the config
  [[ "${plain}" == *"server: https://127.0.0.1:"* ]]
  [ "$(grep -c ' Ready ' <<<"${plain}")" -eq 3 ]
}

# --- namespaces --------------------------------------------------------------

@test "ns lists the cluster's namespaces" {
  ctx kwok-production
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-1; kubb ns'
  for ns in default kube-system app-1 app-2 monitoring; do
    grep -qxF "${ns}" "${KUBB_TEST_LOG}/fzf.input"
  done
}

@test "ns switches namespace for subsequent kubectl commands" {
  ctx kwok-production
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-2; kubb ns; kubectl get pods --no-headers'
  [ "$status" -eq 0 ]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-2" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "app-2" ]
  [ "$(grep -c '^my-deployment-.* Running ' <<<"$output")" -eq 2 ]
}

@test "ns preview shows the namespace's resources" {
  ctx kwok-production
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-2; kubb ns; fzf_preview app-2'
  [ "$status" -eq 0 ]
  [[ "$output" == *"pod/my-deployment-"* ]]
}

# --- namespaces without permission to list them -------------------------------

@test "restricted user cannot list namespaces" {
  run kubectl --context kwok-production-dev get namespaces
  [ "$status" -ne 0 ]
  [[ "$output" == *"Forbidden"* ]]
}

@test "ns with a restricted user switches to the given namespace" {
  ctx kwok-production-dev
  run kubb_session 'kubb ctx; kubb ns app-1; kubb ns app-2; kubectl get pods --no-headers'
  [ "$status" -eq 0 ]
  ! grep -qxF -- "--print-query" "${KUBB_TEST_LOG}/fzf.args"
  [[ "$output" != *"Forbidden"* ]]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-2" ]
  [ "$(grep -c '^my-deployment-.* Running ' <<<"$output")" -eq 2 ]
}

@test "ns with a restricted user offers known namespaces" {
  ctx kwok-production-dev
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=$'"'"'\napp-2'"'"'; kubb ns'
  [ "$status" -eq 0 ]
  grep -qxF -- "--print-query" "${KUBB_TEST_LOG}/fzf.args"
  [ "$(head -n 1 "${KUBB_TEST_LOG}/fzf.input")" = "app-2" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-2" ]
}

@test "ns with a restricted user accepts a typed namespace" {
  ctx kwok-production-dev
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-1 KUBB_TEST_FZF_EXIT=1; kubb ns'
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "app-1" ]
}

@test "ns preview with a restricted user shows resources it may read" {
  ctx kwok-production-dev
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=$'"'"'\napp-2'"'"'; kubb ns; fzf_preview app-2'
  [[ "$output" == *"pod/my-deployment-"* ]]
}
