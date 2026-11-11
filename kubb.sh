KUBB_CONTEXT_RESOURCES="${KUBB_CONTEXT_RESOURCES:-nodes}"
KUBB_NAMESPACE_RESOURCES="${KUBB_NAMESPACE_RESOURCES:-pods,services}"

KUBB_HOOK_CD="${KUBB_HOOK_CD:-}"


_kubb_get_contexts() {
  local files=()
  # zsh aborts on unmatched globs by default; expand them to nothing instead
  [ "$ZSH_VERSION" ] && setopt local_options null_glob
  for f in ~/.kube/configs/*.yaml; do
    [[ -f "$f" ]] && files+=("$f")
  done
  [[ -f ~/.kube/config ]] && files+=(~/.kube/config)
  if [[ ${#files[@]} -gt 0 ]]; then
    yq --no-doc -r '.contexts[] | filename +" "+ .name' "${files[@]}"
  fi
}

_kubb_get_namespaces() {
  kubectl get namespaces -o=jsonpath='{range .items[*].metadata.name}{@}{"\n"}{end}' 2>/dev/null
}

# Namespaces known without cluster-wide list permission: the current one and
# any namespace referenced by a context in the active kubeconfig.
_kubb_get_known_namespaces() {
  {
    echo "${KUBERNETES_NAMESPACE:-default}"
    kubectl config view -o=jsonpath='{range .contexts[*]}{.context.namespace}{"\n"}{end}' 2>/dev/null
  } | awk 'NF && !seen[$0]++'
}

_kubb_get_namespace() {
  local NAMESPACE

  NAMESPACE="$(kubectl config view -o=jsonpath="{.contexts[?(@.name==\"${KUBERNETES_CONTEXT}\")].context.namespace}")"

  if [[ -z "${NAMESPACE}" ]]; then
    echo "default"
  else
    echo "${NAMESPACE}"
  fi
}

_kubb_set_namespace() {
  kubectl config set-context --current --namespace="${1}" 1>/dev/null
  export KUBERNETES_NAMESPACE=${1}
}

_kubb_set_context() {
  local tmpfile quoted

  # Drop the private copy made by a previous context switch
  if [[ "${KUBECONFIG}" == */kubb-kubeconfig.* ]]; then
    rm -f -- "${KUBECONFIG}"
  fi

  tmpfile=$(mktemp --tmpdir kubb-kubeconfig.XXXXXXXXXX)

  # Expand the path now: tmpfile is local and gone by the time the shell exits
  quoted=$(printf '%q' "${tmpfile}")
  if [ "$ZSH_VERSION" ]; then
    eval "zshexit() { rm -f -- ${quoted}; }"
  else
    trap "rm -f -- ${quoted}" EXIT
  fi

  cp "${1}" "${tmpfile}"

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



_kubb_choose_context() {
  local CONTEXT
  CONTEXT=($(_kubb_get_contexts | \
    fzf --query="${1}" \
        --select-1 \
        --with-nth=2 \
        --preview-window=":nohidden" \
        --preview="kubectl --kubeconfig={1} --context={2} config view --minify | \
                   yq --colors 'del(.apiVersion, .kind, .contexts, .current-context)' ; \
                   echo ; \
                   printf '\e[90m%.s─' $(seq -s ' ' 1 $COLUMNS) ; \
                   echo ; \
                   echo ; \
                   kubectl --kubeconfig={1} --context={2} get ${KUBB_CONTEXT_RESOURCES}" \
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

_kubb_choose_namespace() {
  local NAMESPACE

  if [[ -z "${KUBERNETES_CONTEXT}" ]]; then
    echo "Run ctx first"
    return
  fi

  local NAMESPACES
  NAMESPACES="$(_kubb_get_namespaces)"

  if [[ -n "${NAMESPACES}" ]]; then
    NAMESPACE=$(echo "${NAMESPACES}" | \
      fzf --query="${1}" \
          --select-1 \
          --preview="kubectl -n {1} get ${KUBB_NAMESPACE_RESOURCES}" \
    )
  elif [[ -n "${1}" ]]; then
    # Not allowed to list namespaces: trust the name given on the command line
    NAMESPACE="${1}"
  else
    # Not allowed to list namespaces: offer known ones and accept free-form input
    NAMESPACE=$(_kubb_get_known_namespaces | \
      fzf --print-query \
          --header="Cannot list namespaces; pick one or type a name and press enter" \
          --preview="kubectl -n {1} get ${KUBB_NAMESPACE_RESOURCES}" \
      | tail -n 1 \
    )
  fi

  if [[ -z "${NAMESPACE}" ]]; then
    return
  fi

  _kubb_set_namespace "$NAMESPACE"

  _kubb_hook_namespace
}

_kubb_hook_ctx() {
  _kubb_hook_cd
}

_kubb_hook_namespace() { :; }


_kubb_hook_cd() {
  if [[ -n "${KUBB_HOOK_CD}" ]]; then
    pushd "${KUBB_HOOK_CD}" > /dev/null
  fi
}

kubb() {
  case "${1}" in
    ctx|context)
      shift
      _kubb_choose_context "$@"
      ;;
    ns|namespace)
      shift
      _kubb_choose_namespace "$@"
      ;;
    *)
      cat <<EOF
Usage: kubb <command>

Commands:
  ctx, context      Switch Kubernetes context
  ns, namespace     Switch Kubernetes namespace
EOF
      ;;
  esac
}
