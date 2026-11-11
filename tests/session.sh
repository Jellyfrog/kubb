# Runs kubb commands in a fresh interactive-like shell (bash or zsh) and
# records the resulting state, so tests can inspect it after the shell exits.
#
# Usage: <bash|zsh> session.sh '<commands>'
PS1='$ '
source "${KUBB_ROOT}/kubb.sh"

eval "$1"
rc=$?

{
  printf 'KUBERNETES_CONTEXT=%s\n' "${KUBERNETES_CONTEXT}"
  printf 'KUBERNETES_NAMESPACE=%s\n' "${KUBERNETES_NAMESPACE}"
  printf 'KUBECONFIG=%s\n' "${KUBECONFIG}"
  printf 'CURRENT_CONTEXT=%s\n' "$(kubectl config current-context 2>/dev/null)"
  printf 'KUBECONFIG_NAMESPACE=%s\n' "$(kubectl config view --minify -o=jsonpath='{.contexts[0].context.namespace}' 2>/dev/null)"
  printf 'PS1=%s\n' "${PS1}"
  printf 'PWD=%s\n' "${PWD}"
} > "${KUBB_TEST_LOG}/state"

exit "${rc}"
