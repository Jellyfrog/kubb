# Runs kubb commands in a fresh interactive-like shell (bash or zsh) and
# records the resulting state, so tests can inspect it after the shell exits.
#
# Usage: <bash|zsh> session.sh '<commands>' [state name]
PS1='$ '
source "${KUBB_ROOT}/kubb.sh"

# Run the preview command of the last fzf call for an entry, the way fzf would
fzf_preview() {
  bash -c "$(sed -e "s|{1}|$1|g" -e "s|{2}|$2|g" "${KUBB_TEST_LOG}/fzf.preview")"
}

# Record the session state under a name; read it with `state KEY NAME`
record_state() {
  {
    printf 'KUBERNETES_CONTEXT=%s\n' "${KUBERNETES_CONTEXT}"
    printf 'KUBERNETES_NAMESPACE=%s\n' "${KUBERNETES_NAMESPACE}"
    printf 'KUBECONFIG=%s\n' "${KUBECONFIG}"
    printf 'CURRENT_CONTEXT=%s\n' "$(kubectl config current-context 2>/dev/null)"
    printf 'KUBECONFIG_NAMESPACE=%s\n' "$(kubectl config view --minify -o=jsonpath='{.contexts[0].context.namespace}' 2>/dev/null)"
    printf 'PS1=%s\n' "${PS1}"
    printf 'PWD=%s\n' "${PWD}"
  } > "${KUBB_TEST_LOG}/state${1:+.$1}"
}

# Open a second, independent session in the background, like a new terminal
# window: it does not inherit anything kubb set in this one.
new_window() {
  env -u KUBECONFIG -u KUBERNETES_CONTEXT -u KUBERNETES_NAMESPACE \
    "${KUBB_TEST_SHELL}" "${KUBB_ROOT}/tests/session.sh" "$1" "${2:-window2}" &
}

# Synchronise concurrent sessions
signal() { touch "${KUBB_TEST_LOG}/signal.$1"; }
await() {
  local i
  for i in $(seq 100); do
    [ -f "${KUBB_TEST_LOG}/signal.$1" ] && return 0
    sleep 0.1
  done
  echo "timed out waiting for $1" >&2
  return 1
}

eval "$1"
rc=$?

wait  # for windows opened with new_window
record_state "$2"

exit "${rc}"
