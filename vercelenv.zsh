# -----------------------------------------------------------------------------
# vercelenv
# -----------------------------------------------------------------------------
#
# Function: vercelenv
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
# Options:
#   -u, --push           add missing keys
#   -d, --pull           sync production
#   -c, --clean          remove stale keys
#   -a, --all            run all operations
#   -b, --branch-preview scope preview env to current branch
#   -h, --help           show this help and exit
#
# -----------------------------------------------------------------------------



# main entry
function vercelenv() {
  local -a ops=()
  local branchScopedPreview=false
  local replaceExisting=false

  # help
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<-EOF
Usage: vercelenv [OPTIONS]

Options:
  -u, --push           add missing keys
  -d, --pull           sync production
  -l, --list           list environment variables
  -r, --replace        update existing keys instead of skipping
  -c, --clean          remove stale keys
  -a, --all            run all operations
  -b, --branch-preview scope preview env to current branch
  -h, --help           show this help and exit
EOF
    return 0
  fi

  # local color codes
  local ESC=$'\033'
  local RESET="${ESC}[0m"
  local RED="${ESC}[0;31m"
  local GREEN="${ESC}[0;32m"
  local YELLOW="${ESC}[0;33m"
  local BLUE="${ESC}[0;34m"
  local BOLD_RED="${ESC}[1;31m"
  local BOLD_GREEN="${ESC}[1;32m"
  local BOLD_YELLOW="${ESC}[1;33m"
  local BOLD_BLUE="${ESC}[1;34m"

  # helpers (scoped within function, cleaned up on exit)
  function VercelEnvPush() {
    while read -r line; do
      [[ $line == \#* || -z $line ]] && continue

      local key="${line%%=*}"
      local val="${line#*=}"
      val="${val#\"}"; val="${val%\"}"
      val="${val//$'\r'/}"

      for target in development preview production; do
        local -a scope
        if [[ $target == preview && $branchScopedPreview == true ]]; then
          local branch=$(git rev-parse --abbrev-ref HEAD)
          scope=(preview "$branch")
        else
          scope=("$target")
        fi

        local -a existing
        existing=( ${(f)"$(vercel env ls "${scope[@]}" | tail -n +3 | awk '{print $1}')"} )
        if [[ " ${existing[*]} " == *" $key "* ]]; then
          if [[ $replaceExisting == true ]]; then
            echo "${BLUE}🔄 UPDATE${RESET} [${scope[*]}]: ${BOLD_BLUE}$key${RESET}"
            vercel env rm "$key" "${scope[@]}" --yes
            printf "%s" "$val" | vercel env add "$key" "${scope[@]}"
          else
            echo "${YELLOW}⚠️ SKIP${RESET} [${scope[*]}]: ${BOLD_YELLOW}$key${RESET}"
          fi
        else
          echo "${GREEN}✅ ADD${RESET} [${scope[*]}]: ${BOLD_GREEN}$key${RESET}"
          printf "%s" "$val" | vercel env add "$key" "${scope[@]}"
        fi
      done
    done < .env.local
  }

  function VercelEnvPull() {
    echo "${BLUE}🔄 PULL${RESET} [production]: ${BOLD_BLUE}.env.production.local${RESET}"
    vercel env pull .env.production.local --environment production
  }

  function VercelEnvClean() {
    local tmp=$(mktemp)
    for target in development preview production; do
      local -a scope
      if [[ $target == preview && $branchScopedPreview == true ]]; then
        local branch=$(git rev-parse --abbrev-ref HEAD)
        scope=(preview "$branch")
      else
        scope=("$target")
      fi

      echo "${BLUE}🧹 CLEAN${RESET} [${scope[*]}]: stale check"
      vercel env ls "${scope[@]}" \
        | tail -n +3 \
        | awk '{print $1}' \
        > "$tmp"

      while read -r key; do
        [[ -z $key ]] && continue
        if ! grep -q "^$key=" .env.local; then
          echo "${RED}❌ REMOVE${RESET} [${scope[*]}]: ${BOLD_RED}$key${RESET}"
          vercel env rm "$key" "${scope[@]}" --yes
        fi
      done < "$tmp"
    done
    rm "$tmp"
  }

  function VercelEnvList() {
    vercel env list
  }

  # parse flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      -u|--push)           ops+=(push) ;;
      -d|--pull)           ops+=(pull) ;;
      -l|--list)           ops+=(list) ;;
      -c|--clean)          ops+=(clean) ;;
      -a|--all)            ops=(push pull clean) ;;
      -r|--replace)        replaceExisting=true ;;
      -b|--branch-preview) branchScopedPreview=true ;;
      -h|--help)           ops+=(help) ;;
      *) echo "${RED}vercelenv: unknown flag $1${RESET}" >&2; unset -f VercelEnvPush VercelEnvPull VercelEnvClean VercelEnvList; return 1 ;;
    esac
    shift
  done
  (( ${#ops[@]} == 0 )) && ops=(push pull clean)

  [[ " ${ops[*]} " == *" push "* ]] && VercelEnvPush
  [[ " ${ops[*]} " == *" pull "* ]] && VercelEnvPull
  [[ " ${ops[*]} " == *" clean "* ]] && VercelEnvClean
  [[ " ${ops[*]} " == *" list "* ]] && VercelEnvList

  # cleanup helpers
  unset -f VercelEnvPush VercelEnvPull VercelEnvClean VercelEnvList
}

# completion
function _vercelenv() {
  _arguments \
    '-u[add missing keys]' \
    '-d[sync production]' \
    '-l[list envs]' \
    '--list[list envs]' \
    '-r[update existing keys instead of skipping]' \
    '-c[remove stale keys]' \
    '-a[run all operations]' \
    '-b[scope preview env]' \
    '--replace[update existing keys instead of skipping]' \
    '-h[show help]' \
    '--help[show help]'
}
compdef _vercelenv vercelenv