# kubb

A shell utility for fast Kubernetes context and namespace switching using [fzf](https://github.com/junegunn/fzf).

Select a context or namespace from a fuzzy-searchable list with a live preview of cluster resources — no more copy-pasting context names or guessing namespace spellings.

## Features

- **Interactive context switching** — browse all contexts from `~/.kube/configs/*.yaml` and `~/.kube/config` with a live preview showing the kubeconfig and cluster resources
- **Interactive namespace switching** — pick a namespace with a live preview of pods, services, and other resources
- **Shell prompt integration** — automatically adds `[context|namespace]` to your prompt with color coding
- **Hooks** — run custom actions after switching context or namespace (cd to a directory, update helm repos, etc.)
- **Bash and Zsh** support

## Prerequisites

| Tool | Required | Purpose |
|------|----------|---------|
| [kubectl](https://kubernetes.io/docs/tasks/tools/) | Yes | Kubernetes CLI |
| [fzf](https://github.com/junegunn/fzf) | Yes | Fuzzy finder for interactive selection |
| [yq](https://github.com/mikefarah/yq) | Yes | YAML processing for kubeconfig parsing |
| [helm](https://helm.sh/) | No | Repo update hook runs after context switch |

## Installation

Clone the repository:

```sh
git clone https://github.com/Jellyfrog/kubb.git ~/.kubb
```

Source it in your shell config (`~/.bashrc` or `~/.zshrc`):

```sh
source ~/.kubb/kubb.sh
```

Optionally, create aliases for quicker access:

```sh
alias ctx='kubb_choose_context'
alias ns='kubb_choose_namespace'
```

Reload your shell or run `source ~/.bashrc` / `source ~/.zshrc`.

## Kubeconfig layout

kubb reads contexts from two locations:

- `~/.kube/configs/*.yaml` — drop individual kubeconfig files here (one per cluster)
- `~/.kube/config` — the standard kubeconfig file

When you select a context, kubb copies the source kubeconfig to a temporary file and sets `KUBECONFIG` to point to it. This isolates your session from other shells and the temp file is cleaned up on shell exit.

## Usage

### Switch context

```sh
kubb_choose_context        # browse all contexts
kubb_choose_context prod   # pre-filter for "prod"
```

The fzf preview panel shows the kubeconfig details (via `yq`) and a summary of cluster resources (nodes by default).

### Switch namespace

```sh
kubb_choose_namespace          # browse all namespaces
kubb_choose_namespace kube     # pre-filter for "kube"
```

The preview panel shows pods, services, and ingress routes in the selected namespace.

A context must be selected first — if not, you'll see an error message.

## Configuration

All settings use environment variables with sensible defaults. Set them **before** sourcing `kubb.sh`:

```sh
# Resources shown in the context selection preview (default: nodes)
export KUBB_DEFAULT_CONTEXT_RESOURCES="nodes"

# Resources shown in the namespace selection preview (default: pods,services,ingressroute)
export KUBB_DEFAULT_NAMESPACE_RESOURCES="pods,services,deployments"

# Directory to cd into after switching context (default: ~/git/kubernetes)
export KUBB_DEFAULT_HOOK_CD="~/projects/k8s"

# Custom prompt format (set to override the default colored prompt)
export KUBB_PROMPT='[my-custom-prompt]'
```

## Hooks

kubb runs hooks after context and namespace switches. Override these functions in your shell config to customize behavior:

```sh
# Runs after context switch — default: cd to KUBB_DEFAULT_HOOK_CD
kubb_hook_cd() {
  cd ~/my-k8s-manifests/"$KUBERNETES_CONTEXT"
}

# Runs after context switch — default: helm repo update (background)
kubb_hook_helm_repo_update() {
  helm repo update
}

# Runs after namespace switch — default: no-op
_kubb_hook_namespace() {
  echo "Switched to namespace: $KUBERNETES_NAMESPACE"
}
```

## Environment variables set by kubb

After selecting a context/namespace, these variables are exported:

| Variable | Description |
|----------|-------------|
| `KUBECONFIG` | Path to the temporary kubeconfig file |
| `KUBERNETES_CONTEXT` | Name of the active context |
| `KUBERNETES_NAMESPACE` | Name of the active namespace |

## License

MIT
