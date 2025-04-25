# -----------------------------------------------------------------------------
# vercelenv
# -----------------------------------------------------------------------------
#
# Description:
#   Manage Vercel environment variables across targets:
#     • Push: upload .env.local keys to development, preview, production
#     • Pull: sync production vars into .env.production.local
#     • Clean: remove stale keys from Vercel not in .env.local
#
# Usage:
#   vercelenv [OPTIONS]
#
# Options:
#   --push            upload .env.local to Vercel
#   --pull            sync production vars to .env.production.local
#   --clean           remove stale keys from Vercel targets
#   --all             run push, pull, and clean
#   --branch-preview  scope preview operations to current Git branch
#   --help            display this help and exit
#
# -----------------------------------------------------------------------------

# helper: push local vars to Vercel
function VercelEnvPush() {
  while IFS='=' read -r key _; do
    [[ $key == \#* || -z $key ]] && continue

    for target in development preview production; do
      if [[ $target == preview && $branchScopedPreview == true ]]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
        scope=(preview "$branch")
      else
        scope=("$target")
      fi

      vercel env rm  "$key" "${scope[@]}" --yes 2>/dev/null
      vercel env add "$key" "${scope[@]}"
    done
  done < .env.local
}

# helper: pull production vars locally
function VercelEnvPull() {
  vercel env pull .env.production.local production
}

# helper: clean stale keys from Vercel
function VercelEnvClean() {
  tmp=$(mktemp)

  for target in development preview production; do
    vercel env ls "$target" --json | jq -r '.[].key' > "$tmp"

    while read -r key; do
      grep -q "^$key=" .env.local || vercel env rm "$key" "$target" --yes
    done < "$tmp"
  done

  rm "$tmp"
}

# main entry: manage push/pull/clean
function vercelenv() {
  local -a ops=()
  branchScopedPreview=false

  # show help
  for arg; do
    [[ $arg == --help ]] && {
      cat <<-EOF
Usage: vercelenv [--push] [--pull] [--clean] [--all] [--branch-preview] [--help]

Options:
  --push            upload .env.local to Vercel
  --pull            sync production vars to .env.production.local
  --clean           remove stale keys from Vercel targets
  --all             run push, pull, and clean
  --branch-preview  scope preview operations to current Git branch
  --help            display this help and exit
EOF
      return 0
    }
  done

  # parse flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      --push)            ops+=(push) ;;
      --pull)            ops+=(pull) ;;
      --clean)           ops+=(clean) ;;
      --all)             ops=(push pull clean) ;;
      --branch-preview)  branchScopedPreview=true ;;
      *)                 echo "vercelenv: unknown flag $1" >&2; return 1 ;;
    esac
    shift
  done

  # default to all
  (( ${#ops[@]} == 0 )) && ops=(push pull clean)

  [[ " ${ops[*]} " == *" push "* ]] && VercelEnvPush
  [[ " ${ops[*]} " == *" pull "* ]] && VercelEnvPull
  [[ " ${ops[*]} " == *" clean "* ]] && VercelEnvClean
}

# zsh completion
function _vercelenv() {
  _arguments \
    '--push[upload .env.local to Vercel]' \
    '--pull[sync production vars locally]' \
    '--clean[remove stale keys]' \
    '--all[run push, pull, clean]' \
    '--branch-preview[scope preview to git branch]' \
    '--help[show usage]'
}
compdef _vercelenv vercelenv
