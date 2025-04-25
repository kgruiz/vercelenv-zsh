# -----------------------------------------------------------------------------
# vercelenv
# -----------------------------------------------------------------------------
#
# Description:
#   Manage Vercel environment variables across targets:
#     • Push: add missing .env.local keys to development, preview, production
#     • Pull: sync production vars into .env.production.local
#     • Clean: remove stale keys not in .env.local
#
# Usage:
#   vercelenv [OPTIONS]
#
# -----------------------------------------------------------------------------

# push missing vars
function VercelEnvPush() {
  while read -r line; do
    [[ $line == \#* || -z $line ]] && continue

    key="${line%%=*}"
    val="${line#*=}"
    # strip literal surrounding quotes, if any
    val="${val#\"}"
    val="${val%\"}"
    # remove carriage returns
    val="${val//$'\r'/}"

    for target in development preview production; do
      if [[ $target == preview && $branchScopedPreview == true ]]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
        scope=(preview "$branch")
      else
        scope=("$target")
      fi

      echo "PUSH [${scope[*]}]: $key"
      existingKeys=( ${(f)"$(vercel env ls "${scope[@]}" | tail -n +3 | awk '{print $1}')"} )
      if [[ " ${existingKeys[*]} " == *" $key "* ]]; then
        echo "SKIP [${scope[*]}]: $key"
      else
        echo "ADD  [${scope[*]}]: $key"
        printf "%s" "$val" | vercel env add "$key" "${scope[@]}"
      fi
    done
  done < .env.local
}

# pull production vars
function VercelEnvPull() {
  echo "PULL [production]: .env.production.local"
  vercel env pull .env.production.local --environment production
}

# clean stale keys
function VercelEnvClean() {
  tmp=$(mktemp)
  for target in development preview production; do
    if [[ $target == preview && $branchScopedPreview == true ]]; then
      branch=$(git rev-parse --abbrev-ref HEAD)
      scope=(preview "$branch")
    else
      scope=("$target")
    fi

    echo "CLEAN [${scope[*]}]: stale check"
    vercel env ls "${scope[@]}" \
      | tail -n +3 \
      | awk '{print $1}' \
      > "$tmp"

    while read -r key; do
      [[ -z $key ]] && continue
      if ! grep -q "^$key=" .env.local; then
        echo "REMOVE [${scope[*]}]: $key"
        vercel env rm "$key" "${scope[@]}"
      fi
    done < "$tmp"
  done
  rm "$tmp"
}

# main entry
function vercelenv() {
  local -a ops=()
  branchScopedPreview=false

  # help
  for arg; do
    [[ $arg == --help ]] && {
      cat <<-EOF
Usage: vercelenv [--push] [--pull] [--clean] [--all] [--branch-preview] [--help]
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
  (( ${#ops[@]} == 0 )) && ops=(push pull clean)

  [[ " ${ops[*]} " == *" push "* ]] && VercelEnvPush
  [[ " ${ops[*]} " == *" pull "* ]] && VercelEnvPull
  [[ " ${ops[*]} " == *" clean "* ]] && VercelEnvClean
}

# completion
function _vercelenv() {
  _arguments \
    '--push[add missing keys]' \
    '--pull[sync production]' \
    '--clean[remove stale keys]' \
    '--all[run all]' \
    '--branch-preview[scope preview]' \
    '--help[show help]'
}
compdef _vercelenv vercelenv
