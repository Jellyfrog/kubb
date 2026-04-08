# Kubb `/kɵb/`

A bash utility for interactively switching between Kubernetes contexts and namespaces using [fzf](https://github.com/junegunn/fzf).

## Dependencies

- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [fzf](https://github.com/junegunn/fzf)
- [yq](https://github.com/mikefarah/yq)
- [helm](https://helm.sh/) (optional, for repo update hook)

## Setup

```bash
source /path/to/kubb.sh

# optional: short aliases
alias ctx="kubb ctx"
alias ns="kubb ns"
```

## Usage

### Switch context

```bash
kubb ctx        # interactive picker
kubb ctx prod   # pre-filtered query
kubb context    # long form
```

Opens an fzf picker listing all contexts found in `~/.kube/configs/*.yaml` and `~/.kube/config`. The preview pane shows the context config and default resources.

### Switch namespace

```bash
kubb ns             # interactive picker
kubb ns kube-sys    # pre-filtered query
kubb namespace      # long form
```

Requires an active context. Opens an fzf picker for namespaces in the current context.

### Prompt

Once a context is selected, kubb prepends a colored prompt segment showing the active context (red) and namespace (green):

```
[my-cluster|default] $
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `KUBB_DEFAULT_CONTEXT_RESOURCES` | `nodes` | Resources shown in the context picker preview |
| `KUBB_DEFAULT_NAMESPACE_RESOURCES` | `pods,services,ingressroute` | Resources shown in the namespace picker preview |
| `KUBB_DEFAULT_HOOK_CD` | `~/git/kubernetes` | Directory to `pushd` into on context switch |
| `KUBB_PROMPT` | *(auto-generated)* | Custom prompt segment; set to override the default |

## Shell support

Works in both **bash** and **zsh**. Kubb detects the shell and adjusts array indexing, prompt formatting, and temp file cleanup accordingly.
