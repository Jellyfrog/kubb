# Shared setup for the kubb test suite.

KUBB_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup() {
  for tool in kubectl yq; do
    command -v "$tool" >/dev/null || skip "$tool is required"
  done
  yq --version 2>&1 | grep -q mikefarah || skip "mikefarah/yq is required"

  export KUBB_TEST_REAL_KUBECTL="$(command -v kubectl)"
  export KUBB_TEST_LOG="${BATS_TEST_TMPDIR}/log"
  mkdir -p "${KUBB_TEST_LOG}"

  # Isolated home with fixture kubeconfigs
  export HOME="${BATS_TEST_TMPDIR}/home"
  mkdir -p "${HOME}"
  cp -r "${KUBB_ROOT}/tests/fixtures/kube" "${HOME}/.kube"

  export TMPDIR="${BATS_TEST_TMPDIR}/tmp"
  mkdir -p "${TMPDIR}"

  export PATH="${KUBB_ROOT}/tests/stubs:${PATH}"

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
