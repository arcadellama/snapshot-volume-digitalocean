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

main() {
  # Dependency check
  for x in curl jq; do
    if ! command -v "$x" >/dev/null 2>&1; then
      err "$x not installed or available in the PATH"
      exit 1
    fi
  done

  if [ -n "$env_file" ] && [ -r "$env_file" ]; then
    . "$env_file" || exit 1
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
      --env-file)
        if [ -r "$2" ]; then
          . "$2" || exit 1
        fi
        shift 2
        ;;
      *)
        echo "Usage: snapshot.sh [--env-file <path>] [--daily|--weekly|--monthly]>"
        exit 1
        ;;
    esac
  done

  ## check value of predefined variable
  if [ "$api" == "" ] || [ "$snapshot_name" == "" ] || [ "$snapshot_tag" == "" ] || [ "$volume_name" == "" ]; then
    err "Please check your variable value"
    exit 1
  fi

  ## get volume id
  if ! volume_id=$(curl -sS -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes?name=$volume_name" \
    | jq -r '.volumes[].id' 2>&1); then
    echo >&2 "$volume_id"
    err "Unable to get volume id."
    exit 1
  fi

  # get snaphost id that would deleted
  if ! snapshot_id=$(curl -sS -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots" \
    | jq '.snapshots | map(select((.created_at < "'$now'" ))) | map(select(.tags[] | contains ("'$snapshot_tag'") ))' \
    | jq -r '.[].id' 2>&1); then
    err "Unable to get snapshot id."
    echo >&2 "$snapshot_id"
    exit 1
  fi

  ## delete snapshot
  if [ -n "$snapshot_id" ]; then
    if ! delete_id="$(curl -sS -X DELETE \
      -H 'Content-Type: application/json' \
      -H 'Authorization: Bearer '$api \
      "https://api.digitalocean.com/v2/snapshots/$snapshot_id" \
      | jq -r '.id' 2>&1)"; then
      echo >&2 "$delete_id"
      err "Unable to delete snapshot."
      exit 1
    fi

    # Deletion returns nothing, so an ID is a problem
    if [ -n "$delete_id" ]; then
      echo >&2 "$delete_id"
      err "Unknown error deleting snapshot $snapshot_id."
      exit 1
    fi

    inf "Deleted snapshot id: $snapshot_id"
  fi

  ## create new snapshot today
  if ! create_id="$(curl -sS -X POST \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    -d '{"name":"'$snapshot_name'","tags":["'$snapshot_tag'"]}' \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots" \
    | jq -r '.snapshots.id' 2>&1)"; then
    echo >&2 "$create_id"
    err "Unable to create new snapshot"
    exit 1
  fi

  # Error out if no creation id
  if [ "$create_id" = "null" ] || [ -z "$create_id" ]; then
    err "Unknown error creating new snapshot."
    exit 1
  fi

  inf "Created new snapshot id $create_id with tag: $snapshot_tag"
}

main "$@"
