# Kubb `/kɵb/`

A bash utility for interactively switching between Kubernetes contexts and namespaces using [fzf](https://github.com/junegunn/fzf).

![demo](demo.gif)

## Dependencies

- [kubectl](https://kubernetes.io/docs/reference/kubectl/)
- [fzf](https://github.com/junegunn/fzf)
- [yq](https://github.com/mikefarah/yq)
## Setup

```bash
source /path/to/kubb.sh

# optional: short aliases
alias ctx="kubb ctx"
alias ns="kubb ns"

# optional: update helm repos on context switch
_kubb_hook_ctx() {
  _kubb_hook_cd
  (helm repo update > /dev/null &)
}
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

If you lack permission to list namespaces in the cluster (common with namespace-scoped RBAC), kubb falls back to:

- `kubb ns <name>`: switches straight to `<name>`.
- `kubb ns`: offers the current namespace plus any namespaces referenced in your kubeconfig contexts, and accepts a free-typed name (type it and press enter).

### Prompt

Once a context is selected, kubb prepends a colored prompt segment showing the active context (red) and namespace (green):

```
[my-cluster|default] $
```

## Configuration

| Variable | Default | Description |
|---|---|---|
| `KUBB_CONTEXT_RESOURCES` | `nodes` | Resources shown in the context picker preview |
| `KUBB_NAMESPACE_RESOURCES` | `pods,services` | Resources shown in the namespace picker preview |
| `KUBB_HOOK_CD` | *(unset)* | Directory to `pushd` into on context switch |
| `KUBB_PROMPT` | *(auto-generated)* | Custom prompt segment; set to override the default |

## Shell support

Works in both **bash** and **zsh**. Kubb detects the shell and adjusts array indexing, prompt formatting, and temp file cleanup accordingly.

## Tests

The test suite uses [bats](https://github.com/bats-core/bats-core) and needs `kubectl` and [yq](https://github.com/mikefarah/yq). No cluster is required: `kubectl` calls that would reach a cluster and `fzf` are replaced by stubs in `tests/stubs`, while kubeconfig handling runs against the real `kubectl` using fixtures in `tests/fixtures`.

```bash
bats tests/                       # run in bash
KUBB_TEST_SHELL=zsh bats tests/   # run in zsh
```

Integration tests run kubb against live [kwok](https://kwok.sigs.k8s.io/) clusters, including a user without permission to list namespaces. They need [kwokctl](https://kwok.sigs.k8s.io/docs/user/installation/) and are skipped when the clusters are missing:

```bash
tests/integration/setup-kwok.sh   # creates the clusters, adds them to ~/.kube/config
bats tests/integration/           # KUBB_TEST_SHELL=zsh works here too

# without docker
KWOK_RUNTIME=binary tests/integration/setup-kwok.sh
```
