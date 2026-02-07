# kubb - Kubernetes context and namespace switcher
#
# Source this file in your .bashrc or .zshrc:
#   source /path/to/kubb.sh
#
# Dependencies: kubectl, yq, fzf, helm (optional)

# Resources shown in the fzf preview when selecting a context
KUBB_DEFAULT_CONTEXT_RESOURCES="${KUBB_DEFAULT_CONTEXT_RESOURCES:-nodes}"

# Resources shown in the fzf preview when selecting a namespace
KUBB_DEFAULT_NAMESPACE_RESOURCES="${KUBB_DEFAULT_NAMESPACE_RESOURCES:-pods,services,ingressroute}"

# Directory to cd into after switching context
KUBB_DEFAULT_HOOK_CD="${KUBB_DEFAULT_HOOK_CD:-~/git/kubernetes}"

###

# List all contexts from kubeconfig files as "<file> <context-name>" pairs
_kubb_get_contexts() {
  yq --no-doc \
     -r '.contexts[] | filename +" "+ .name' \
     ~/.kube/configs/*.yaml \
     ~/.kube/config 2>/dev/null
}

# Print the current context name
_kubb_get_context() {
  kubectl config view -o=jsonpath='{.current-context}'
}

# List all namespace names in the current context
_kubb_get_namespaces() {
  kubectl get namespaces -o=jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}'
}

# Print the current namespace (defaults to "default" if unset)
_kubb_get_namespace() {
  local NAMESPACE

  NAMESPACE="$(kubectl config view -o=jsonpath="{.contexts[?(@.name==\"${KUBERNETES_CONTEXT}\")].context.namespace}")"

  if [[ -z "${NAMESPACE}" ]]; then
    echo "default"
  else
    echo "${NAMESPACE}"
  fi
}

# Set the active namespace on the current context
_kubb_set_namespace() {
  kubectl config set-context --current --namespace="${1}" 1>/dev/null
  export KUBERNETES_NAMESPACE=${1}
}

# Switch to a context by copying its kubeconfig to a temp file
# and updating the shell prompt to show context|namespace
_kubb_set_context() {
  tmpfile=$(mktemp --tmpdir kubb-kubeconfig.XXXXXXXXXX)

  if [ "$ZSH_VERSION" ]; then
    zshexit() { rm -f -- "$tmpfile" }
  else
    trap 'rm -f -- "$tmpfile"' EXIT
  fi

  # Copy content only, do not preserve the source file's permissions
  cat "${1}" > "${tmpfile}"

  export KUBECONFIG="${tmpfile}"
  kubectl config use-context "${2}" 1>/dev/null

  export KUBERNETES_CONTEXT="${2}"
  export KUBERNETES_NAMESPACE=$(_kubb_get_namespace)

  if [[ -z "${KUBB_PROMPT}" ]]; then
    if [ "$ZSH_VERSION" ]; then
      KUBB_PROMPT='[%F{red}$KUBERNETES_CONTEXT%f|%F{green}$KUBERNETES_NAMESPACE%f]'
    else
      KUBB_PROMPT='[\[\e[31m\]$KUBERNETES_CONTEXT\[\e[0m\]|\[\e[32m\]$KUBERNETES_NAMESPACE\[\e[0m\]]'
    fi

    PS1="$KUBB_PROMPT $PS1"
  fi
}

# Interactively select a Kubernetes context using fzf.
# Optionally pass a query string to pre-filter the list.
kubb_choose_context() {
  local CONTEXT

  CONTEXT=($(_kubb_get_contexts | \
    fzf --query="${1}" \
        --select-1 \
        --with-nth=2 \
        --preview-window=":nohidden" \
        --preview="kubectl --kubeconfig={1} --context={2} config view --minify | \
                   yq --colors ; \
                   echo ; \
                   printf '\e[90m%.s─' \$(seq -s ' ' 1 \$COLUMNS) ; \
                   echo ; \
                   echo ; \
                   kubectl --kubeconfig={1} --context={2} get ${KUBB_DEFAULT_CONTEXT_RESOURCES}" \
  ))

  if [[ -z "${CONTEXT}" ]]; then
    return
  fi

  if [ "$ZSH_VERSION" ]; then
    _kubb_set_context "${CONTEXT[1]}" "${CONTEXT[2]}"
  else
    _kubb_set_context "${CONTEXT[0]}" "${CONTEXT[1]}"
  fi

  _kubb_hook_ctx
}

# Interactively select a namespace using fzf.
# Requires a context to be selected first.
# Optionally pass a query string to pre-filter the list.
kubb_choose_namespace() {
  local NAMESPACE

  if [[ -z "${KUBERNETES_CONTEXT}" ]]; then
    echo "No context selected. Run kubb_choose_context first."
    return 1
  fi

  NAMESPACE=$(_kubb_get_namespaces | \
    fzf --query="${1}" \
        --select-1 \
        --preview="kubectl -n {1} get ${KUBB_DEFAULT_NAMESPACE_RESOURCES}" \
  )

  if [[ -z "${NAMESPACE}" ]]; then
    return
  fi

  _kubb_set_namespace "$NAMESPACE"

  _kubb_hook_namespace
}

# Hooks executed after switching context
_kubb_hook_ctx() {
  kubb_hook_cd
  kubb_hook_helm_repo_update
}

# Hook executed after switching namespace (override to customize)
_kubb_hook_namespace() {
  :
}

# Update helm repos in the background after a context switch
kubb_hook_helm_repo_update() {
  if command -v helm &>/dev/null; then
    (helm repo update > /dev/null 2>&1 &)
  fi
}

# cd to the configured kubernetes directory after a context switch
kubb_hook_cd() {
  local target
  target="${KUBB_DEFAULT_HOOK_CD/#\~/$HOME}"
  if [[ -d "${target}" ]]; then
    pushd "${target}" > /dev/null
  fi
}
