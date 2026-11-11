#!/usr/bin/env bats
# Run with:  bats tests/                       (bash)
#            KUBB_TEST_SHELL=zsh bats tests/   (zsh)

load test_helper

# --- usage -------------------------------------------------------------------

@test "kubb without a command prints usage" {
  run kubb_session 'kubb'
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: kubb <command>"* ]]
  [[ "$output" == *"ctx, context"* ]]
  [[ "$output" == *"ns, namespace"* ]]
}

@test "kubb with an unknown command prints usage" {
  run kubb_session 'kubb bogus'
  [[ "$output" == *"Usage: kubb <command>"* ]]
}

# --- context listing ---------------------------------------------------------

@test "contexts are listed from ~/.kube/configs/*.yaml and ~/.kube/config" {
  run kubb_session '_kubb_get_contexts'
  [ "$status" -eq 0 ]
  [[ "$output" == *"${HOME}/.kube/configs/prod.yaml prod"* ]]
  [[ "$output" == *"${HOME}/.kube/configs/prod.yaml prod-admin"* ]]
  [[ "$output" == *"${HOME}/.kube/config staging"* ]]
  [ "${#lines[@]}" -eq 3 ]
}

@test "contexts listing works with only ~/.kube/config" {
  rm -r "${HOME}/.kube/configs"
  run kubb_session '_kubb_get_contexts'
  [ "$status" -eq 0 ]
  [ "$output" = "${HOME}/.kube/config staging" ]
}

@test "contexts listing is empty without any kubeconfig" {
  rm -r "${HOME}/.kube"
  run kubb_session '_kubb_get_contexts'
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# --- switching context -------------------------------------------------------

@test "ctx switches context and picks up its namespace" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx'
  [ "$status" -eq 0 ]
  [ "$(state KUBERNETES_CONTEXT)" = "prod" ]
  [ "$(state CURRENT_CONTEXT)" = "prod" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
}

@test "ctx defaults the namespace to 'default' when the context has none" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod-admin"
  run kubb_session 'kubb ctx'
  [ "$(state KUBERNETES_CONTEXT)" = "prod-admin" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "default" ]
}

@test "ctx works on contexts from ~/.kube/config" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/config staging"
  run kubb_session 'kubb context'
  [ "$(state KUBERNETES_CONTEXT)" = "staging" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "team-a" ]
}

@test "ctx passes the query to fzf and lists all contexts" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx pro'
  fzf_arg "--query=pro"
  fzf_arg "--select-1"
  [ "$(wc -l < "${KUBB_TEST_LOG}/fzf.input")" -eq 3 ]
}

@test "ctx works on a private copy of the kubeconfig" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  original="$(cat "${HOME}/.kube/configs/prod.yaml")"
  run kubb_session 'kubb ctx; kubb ns app-2'

  kubeconfig="$(state KUBECONFIG)"
  [[ "${kubeconfig}" == "${TMPDIR}"/kubb-kubeconfig.* ]]
  [ "$(cat "${HOME}/.kube/configs/prod.yaml")" = "${original}" ]
}

@test "ctx removes the private kubeconfig copy when the shell exits" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx'
  [ -n "$(state KUBECONFIG)" ]
  [ ! -e "$(state KUBECONFIG)" ]
}

@test "ctx leaves no kubeconfig copies behind after several switches" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx; kubb ctx; kubb ctx'
  [ "$status" -eq 0 ]
  [ -z "$(ls -A "${TMPDIR}")" ]
}

@test "ctx in a nested shell keeps the parent's kubeconfig copy" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  # the child inherits the exported KUBECONFIG of the parent
  run kubb_session 'kubb ctx
                    "${KUBB_TEST_SHELL}" -c "source \"\${KUBB_ROOT}/kubb.sh\"; kubb ctx"
                    [ -f "${KUBECONFIG}" ] && echo "parent kubeconfig intact"'
  [[ "$output" == *"parent kubeconfig intact"* ]]
  [ "$(state CURRENT_CONTEXT)" = "prod" ]
}

@test "ctx in a nested shell leaves the parent's copy to the parent" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx
                    "${KUBB_TEST_SHELL}" -c "source \"\${KUBB_ROOT}/kubb.sh\"; kubb ctx"'
  [ "$status" -eq 0 ]
  # child cleaned up its own copy, parent removed its copy on exit
  [ -z "$(ls -A "${TMPDIR}")" ]
}

@test "ctx does nothing when the picker is cancelled" {
  export KUBB_TEST_FZF_OUTPUT="" KUBB_TEST_FZF_EXIT=130
  run kubb_session 'kubb ctx'
  [ -z "$(state KUBERNETES_CONTEXT)" ]
  [ -z "$(state KUBECONFIG)" ]
  [ "$(state PS1)" = '$ ' ]
}

@test "ctx prepends the prompt segment only once" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx; kubb ctx'
  ps1="$(state PS1)"
  [[ "${ps1}" == *'$KUBERNETES_CONTEXT'*'$KUBERNETES_NAMESPACE'*'] $ ' ]]
  [ "$(grep -o 'KUBERNETES_CONTEXT' <<<"${ps1}" | wc -l)" -eq 1 ]
}

@test "ctx changes into KUBB_HOOK_CD" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_HOOK_CD="${BATS_TEST_TMPDIR}/workdir"
  mkdir -p "${KUBB_HOOK_CD}"
  run kubb_session 'kubb ctx'
  [ "$(state PWD)" = "${KUBB_HOOK_CD}" ]
}

@test "ctx runs an overridden _kubb_hook_ctx" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session '_kubb_hook_ctx() { echo "hook: $KUBERNETES_CONTEXT"; }; kubb ctx'
  [[ "$output" == *"hook: prod"* ]]
}

# --- switching namespace -----------------------------------------------------

@test "ns requires a context first" {
  run kubb_session 'kubb ns'
  [[ "$output" == *"Run ctx first"* ]]
  ! fzf_was_called
}

@test "ns switches to the selected namespace" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-2; kubb ns'
  [ "$status" -eq 0 ]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-2" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "app-2" ]
}

@test "ns lists cluster namespaces and passes the query to fzf" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=kube-system; kubb namespace kube'
  fzf_arg "--query=kube"
  fzf_arg "--select-1"
  [ "$(cat "${KUBB_TEST_LOG}/fzf.input")" = "${KUBB_TEST_NAMESPACES}" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "kube-system" ]
}

@test "ns does nothing when the picker is cancelled" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT="" KUBB_TEST_FZF_EXIT=130; kubb ns'
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "app-1" ]
}

@test "ns runs an overridden _kubb_hook_namespace" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  run kubb_session '_kubb_hook_namespace() { echo "hook: $KUBERNETES_NAMESPACE"; }
                    kubb ctx; export KUBB_TEST_FZF_OUTPUT=app-2; kubb ns'
  [[ "$output" == *"hook: app-2"* ]]
}

# --- switching namespace without permission to list namespaces ---------------

@test "ns without list permission switches directly to the given name" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_TEST_FORBIDDEN=1
  run kubb_session 'kubb ctx; rm "${KUBB_TEST_LOG}/fzf.args"; kubb ns my-team'
  [ "$status" -eq 0 ]
  ! fzf_was_called
  [ "$(state KUBERNETES_NAMESPACE)" = "my-team" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "my-team" ]
}

@test "ns without list permission does not show the kubectl error" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_TEST_FORBIDDEN=1
  run kubb_session 'kubb ctx; kubb ns my-team'
  [[ "$output" != *"Forbidden"* ]]
}

@test "ns without list permission offers known namespaces" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_TEST_FORBIDDEN=1
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=$'"'"'\napp-1'"'"'; kubb ns'
  fzf_arg "--print-query"
  # current namespace first, then namespaces from kubeconfig contexts, deduplicated
  [ "$(cat "${KUBB_TEST_LOG}/fzf.input")" = "app-1" ]
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
}

@test "ns without list permission accepts a typed namespace" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod-admin"
  export KUBB_TEST_FORBIDDEN=1
  # fzf with --print-query prints only the query when nothing matches
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=typed-ns KUBB_TEST_FZF_EXIT=1; kubb ns'
  [ "$(state KUBERNETES_NAMESPACE)" = "typed-ns" ]
  [ "$(state KUBECONFIG_NAMESPACE)" = "typed-ns" ]
}

@test "ns without list permission prefers the selected entry over the query" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_TEST_FORBIDDEN=1
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT=$'"'"'ap\napp-1'"'"'; kubb ns'
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
}

@test "ns without list permission does nothing when the picker is cancelled" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod"
  export KUBB_TEST_FORBIDDEN=1
  run kubb_session 'kubb ctx; export KUBB_TEST_FZF_OUTPUT="" KUBB_TEST_FZF_EXIT=130; kubb ns'
  [ "$(state KUBERNETES_NAMESPACE)" = "app-1" ]
}

@test "known namespaces include those of other kubeconfig contexts" {
  export KUBB_TEST_FZF_OUTPUT="${HOME}/.kube/configs/prod.yaml prod-admin"
  run kubb_session 'kubb ctx; _kubb_get_known_namespaces'
  [ "${lines[0]}" = "default" ]
  [ "${lines[1]}" = "app-1" ]
  [ "${#lines[@]}" -eq 2 ]
}
