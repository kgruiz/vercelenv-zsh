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

# color codes (only define if not already set)
if [[ -z $ESC ]];        then readonly ESC="\033";          fi
if [[ -z $RESET ]];      then readonly RESET="${ESC}[0m";   fi
if [[ -z $RED ]];        then readonly RED="${ESC}[0;31m";   fi
if [[ -z $GREEN ]];      then readonly GREEN="${ESC}[0;32m"; fi
if [[ -z $YELLOW ]];     then readonly YELLOW="${ESC}[0;33m";fi
if [[ -z $BLUE ]];       then readonly BLUE="${ESC}[0;34m";  fi
if [[ -z $BOLD_RED ]];   then readonly BOLD_RED="${ESC}[1;31m";   fi
if [[ -z $BOLD_GREEN ]]; then readonly BOLD_GREEN="${ESC}[1;32m"; fi
if [[ -z $BOLD_YELLOW ]];then readonly BOLD_YELLOW="${ESC}[1;33m";fi
if [[ -z $BOLD_BLUE ]];  then readonly BOLD_BLUE="${ESC}[1;34m";  fi

# push missing vars
function VercelEnvPush() {
  while read -r line; do
    [[ $line == \#* || -z $line ]] && continue

    key="${line%%=*}"
    val="${line#*=}"
    val="${val#\"}"; val="${val%\"}"
    val="${val//$'\r'/}"

    for target in development preview production; do
      if [[ $target == preview && $branchScopedPreview == true ]]; then
        branch=$(git rev-parse --abbrev-ref HEAD)
        scope=(preview "$branch")
      else
        scope=("$target")
      fi

      existing=( ${(f)"$(vercel env ls "${scope[@]}" | tail -n +3 | awk '{print $1}')"} )
      if [[ " ${existing[*]} " == *" $key "* ]]; then
        echo "${YELLOW}⚠️ SKIP${RESET} [${scope[*]}]: ${BOLD_YELLOW}$key${RESET}"
      else
        echo "${GREEN}✅ ADD${RESET} [${scope[*]}]: ${BOLD_GREEN}$key${RESET}"
        printf "%s" "$val" | vercel env add "$key" "${scope[@]}"
      fi
    done
  done < .env.local
}

# pull production vars
function VercelEnvPull() {
  echo "${BLUE}🔄 PULL${RESET} [production]: ${BOLD_BLUE}.env.production.local${RESET}"
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

    echo "${BLUE}🧹 CLEAN${RESET} [${scope[*]}]: stale check"
    vercel env ls "${scope[@]}" \
      | tail -n +3 \
      | awk '{print $1}' \
      > "$tmp"

    while read -r key; do
      [[ -z $key ]] && continue
      if ! grep -q "^$key=" .env.local; then
        echo "${RED}❌ REMOVE${RESET} [${scope[*]}]: ${BOLD_RED}$key${RESET}"
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
  if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    cat <<-EOF
Usage: vercelenv [OPTIONS]

Options:
  -u, --push           add missing keys
  -d, --pull           sync production
  -c, --clean          remove stale keys
  -a, --all            run all operations
  -b, --branch-preview scope preview env to current branch
  -h, --help           show this help and exit
EOF
    return 0
  fi

  # parse flags
  while [[ $# -gt 0 ]]; do
    case $1 in
      -u|--push)           ops+=(push) ;;
      -d|--pull)           ops+=(pull) ;;
      -c|--clean)          ops+=(clean) ;;
      -a|--all)            ops=(push pull clean) ;;
      -b|--branch-preview) branchScopedPreview=true ;;
      -h|--help)           ops+=(help) ;;
      *) echo "${RED}vercelenv: unknown flag $1${RESET}" >&2; return 1 ;;
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
    '-u[add missing keys]' \
    '-d[sync production]' \
    '-c[remove stale keys]' \
    '-a[run all operations]' \
    '-b[scope preview env]' \
    '-h[show help]' \
    '--help[show help]'
}
compdef _vercelenv vercelenv
