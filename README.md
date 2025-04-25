# vercelenv-zsh

**`vercelenv` provides a unified Zsh function to manage Vercel environment variables (push, pull, clean).**

Keep your local `.env.local` in sync with Vercel’s development, preview, and production targets, and prune stale entries.

## Key Features

-   **Push**: Upload keys from `.env.local` to all targets (`development`, `preview`, `production`).
-   **Pull**: Download production variables into `.env.production.local`.
-   **Clean**: Remove variables in Vercel not listed in `.env.local`.
-   **Branch-Scoped Preview**: Optionally scope preview vars to current Git branch.
-   **Zsh Autocomplete**: Tab-completion for commands and flags.
-   **Single Script**: Lightweight `vercelenv.zsh` file.

## Installation

1.  **Clone or Download**

    ```bash
    # Clone repo
    git clone https://github.com/kgruiz/vercelenv-zsh.git \
      ~/.config/zsh/plugins/vercelenv-zsh

    # Or download single file
    mkdir -p ~/.config/zsh/plugins/vercelenv-zsh
    curl -o ~/.config/zsh/plugins/vercelenv-zsh/vercelenv.zsh \
      https://raw.githubusercontent.com/kgruiz/vercelenv-zsh/main/vercelenv.zsh
    ```

2.  **Source in `.zshrc`**

    ```bash
    # init zsh completion
    autoload -Uz compinit
    compinit

    # load vercelenv
    VERCELENV_PATH="$HOME/.config/zsh/plugins/vercelenv-zsh/vercelenv.zsh"
    if [ -f "$VERCELENV_PATH" ]; then
        source "$VERCELENV_PATH" 2>/dev/null \
          || echo "Error: failed to source vercelenv.zsh" >&2
    else
        echo "Error: vercelenv.zsh not found at $VERCELENV_PATH" >&2
    fi
    ```

3.  **Apply Changes**
    ```bash
    source ~/.zshrc
    ```

## Usage Guide

```bash
# push + pull + clean (default)
❯ vercelenv

# push only
❯ vercelenv --push

# pull only
❯ vercelenv --pull

# clean only
❯ vercelenv --clean

# all + branch-scoped preview
❯ vercelenv --all --branch-preview

# show help
❯ vercelenv --help
```

## Dependencies

-   **Vercel CLI**: Install via pnpm: `pnpm add -g vercel` (or `npm install -g vercel`).

## Configuration Details

-   **`.env.local`**: Source of truth for variables to push.
-   **`.env.production.local`**: Snapshot file for pulled production vars.
-   **Vercel CLI**: Requires `vercel` in `$PATH`.

## Contributing

Issues and pull requests welcome. See [issues](https://github.com/kgruiz/vercelenv-zsh/issues).

## License

Distributed under the **GNU GPL v3.0**.
See [LICENSE](LICENSE) or <https://www.gnu.org/licenses/gpl-3.0.html> for details.
