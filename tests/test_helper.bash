# Shared setup for the kubb test suite.

KUBB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

setup() {
  kubb_test_setup stubbed
}

# mode "stubbed": fake cluster, kubeconfigs from tests/fixtures
# mode "live":    real cluster, kubeconfig from KUBB_TEST_KUBECONFIG
#                 (default ~/.kube/config); only fzf is stubbed
kubb_test_setup() {
  local mode="$1"

  for tool in kubectl yq; do
    command -v "$tool" >/dev/null || skip "$tool is required"
  done
  yq --version 2>&1 | grep -q mikefarah || skip "mikefarah/yq is required"

  export KUBB_TEST_REAL_KUBECTL="$(command -v kubectl)"
  export KUBB_TEST_LOG="${BATS_TEST_TMPDIR}/log"
  mkdir -p "${KUBB_TEST_LOG}"

  local kubeconfig="${KUBB_TEST_KUBECONFIG:-${HOME}/.kube/config}"

  # Isolated home
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"

  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "${TMPDIR}"

  if [[ "${mode}" == live ]]; then
    [[ -f "${kubeconfig}" ]] || skip "no kubeconfig at ${kubeconfig}"
    mkdir -p "${HOME}/.kube"
    "${KUBB_TEST_REAL_KUBECTL}" config view --raw --kubeconfig="${kubeconfig}" > "${HOME}/.kube/config"

    mkdir -p "${BATS_TEST_TMPDIR}/bin"
    ln -s "${KUBB_ROOT}/tests/stubs/fzf" "${BATS_TEST_TMPDIR}/bin/fzf"
    export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
  else
    cp -r "${KUBB_ROOT}/tests/fixtures/kube" "${HOME}/.kube"
    export PATH="${KUBB_ROOT}/tests/stubs:${PATH}"
  fi

  export KUBB_TEST_NAMESPACES=$'default\nkube-system\napp-1\napp-2'
  unset KUBB_TEST_FORBIDDEN KUBB_TEST_FZF_OUTPUT KUBB_TEST_FZF_EXIT
  unset KUBECONFIG KUBERNETES_CONTEXT KUBERNETES_NAMESPACE KUBB_PROMPT KUBB_HOOK_CD

  export KUBB_ROOT
  KUBB_TEST_SHELL="${KUBB_TEST_SHELL:-bash}"
  command -v "${KUBB_TEST_SHELL}" >/dev/null || skip "${KUBB_TEST_SHELL} is required"
}

# Run kubb commands in a fresh shell; use with bats' `run`.
#   run kubb_session 'kubb ctx prod'
kubb_session() {
  "${KUBB_TEST_SHELL}" "${KUBB_ROOT}/tests/session.sh" "$1"
}

# Value recorded by the last kubb_session, e.g. `state KUBERNETES_NAMESPACE`
state() {
  sed -n "s/^$1=//p" "${KUBB_TEST_LOG}/state"
}

fzf_was_called() {
  [[ -f "${KUBB_TEST_LOG}/fzf.args" ]]
}

fzf_arg() {
  grep -qxF -- "$1" "${KUBB_TEST_LOG}/fzf.args"
}
