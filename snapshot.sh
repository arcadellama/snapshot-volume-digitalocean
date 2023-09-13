#!/bin/bash
# shellcheck disable=SC1090,SC2086

set -eu
LC_ALL=C
export TZ='UTC'

api=""
env_file=""
now=$(date +"%Y-%m-%d")
snapshot_name=""
snapshot_tag=""
volume_name=""

inf() {
  echo "[$(date '+%Y-%m-%dT%TZ')] $*"
}

err() {
  echo >&2 "[$(date '+%Y-%m-%dT%TZ')] ERROR: $*"
}

http__curl() (
  # Usage: use as a stand-in for curl, less the -sS options.
  retval=0 response="" ret=""
  if ! response=$(mktemp 2>&1); then
    printf %s\\n "$response"
    return 1
  fi

  if ! ret=$("$(command -v curl)" -sS \
    -o "$response" \
    -w '%{http_code}' \
    "$@" 2>&1); then
    printf %s\\n "$ret" >"$response"
    retval=1
  fi

  if [ $retval -eq 0 ] && [ "$ret" -ge 400 ]; then
    printf 'HTTP Error Code: %s\n' "$ret"
    retval=1
  fi

  cat "$response"
  rm -rf "$response"
  return $retval
)

main() {
  # Dependency check
  for x in curl jq; do
    if ! command -v "$x" >/dev/null 2>&1; then
      err "$x not installed or available in the PATH"
      return 1
    fi
  done

  if [ -n "$env_file" ] && [ -r "$env_file" ]; then
    . "$env_file" || return 1
  fi

  while [ $# -gt 0 ]; do
    case "$1" in
      --daily)
        snapshot_tag="daily_backup"
        shift
        ;;
      --weekly)
        snapshot_tag="weekly_backup"
        shift
        ;;
      --monthly)
        snapshot_tag="monthly_backup"
        shift
        ;;
      --name)
        snapshot_name="$2"
        shift 2
        ;;
      --env-file)
        if [ -r "$2" ]; then
          . "$2" || return 1
        fi
        shift 2
        ;;
      *)
        echo "Usage: snapshot.sh [--env-file <path>] [--daily|--weekly|--monthly]>"
        return 1
        ;;
    esac
  done

  ## check value of predefined variable
  if [ "$api" == "" ] || [ "$snapshot_name" == "" ] || [ "$snapshot_tag" == "" ] || [ "$volume_name" == "" ]; then
    err "Please check your variable value"
    return 1
  fi

  ## get volume id
  if ! volume_json=$(http__curl -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes?name=$volume_name" 2>&1); then
    echo >&2 "$volume_json"
    err "Unable to get volume id."
    return 1
  fi

  if ! volume_id="$(echo "$volume_json" \
    | jq -r '.volumes[].id' 2>&1)"; then
    echo >&2 "$volume_id"
    err "Unable to get volume id."
    return 1
  fi

  # get snaphost id that would deleted
  if ! snapshot_json=$(http__curl -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots" 2>&1); then
    err "Unable to get snapshot id."
    echo >&2 "$snapshot_json"
    return 1
  fi

  if ! snapshot_id=$(echo "$snapshot_json" \
    | jq '.snapshots | map(select((.created_at < "'$now'" ))) | map(select(.tags[] | contains ("'$snapshot_tag'") ))' \
    | jq -r '.[].id' 2>&1); then
    err "Unable to get snapshot id."
    echo >&2 "$snapshot_id"
    return 1
  fi

  ## delete snapshot
  if [ -n "$snapshot_id" ]; then
    if ! delete_json="$(http__curl -X DELETE \
      -H 'Content-Type: application/json' \
      -H 'Authorization: Bearer '$api \
      "https://api.digitalocean.com/v2/snapshots/$snapshot_id" 2>&1)"; then
      echo >&2 "$delete_json"
      err "Unable to delete snapshot."
      return 1
    fi
    inf "Deleted snapshot id: $snapshot_id"
  fi

  ## create new snapshot today
  if ! create_json="$(http__curl -X POST \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    -d '{"name":"'$snapshot_name'","tags":["'$snapshot_tag'"]}' \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots" 2>&1)"; then
    echo >&2 "$create_json"
    err "Unable to create new snapshot"
    return 1
  fi

  inf "Created new snapshot with tag: $snapshot_tag"
}

main "$@"
