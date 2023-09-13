#!/bin/bash

api=""
env_file=""
now=$(date +"%Y-%m-%d")
snapshot_name=""
snapshot_tag=""
volume_name=""

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
  echo "Please check your variable value"
  exit 1
fi

## get volume id
volume_id=$(curl -X GET \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer '$api \
  "https://api.digitalocean.com/v2/volumes?name=$volume_name" \
  | jq -r '.volumes[].id') || { echo "$volume_id" ; exit 1; }

# get snaphost id that would deleted
snapshot_id=$(curl -X GET \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer '$api \
  "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots?page=1&per_page=1" \
  | jq '.snapshots | map(select((.created_at < "'$now'" ))) | map(select(.tag contains "'$snapshot_name'"))' \
  | jq -r '.[].id') || { echo "$snapshot_id" ; exit 1 ; }

## delete snapshot
curl -X DELETE \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer '$api \
  "https://api.digitalocean.com/v2/snapshots/$snapshot_id"

## create new snapshot today
curl -X POST \
  -H 'Content-Type: application/json' \
  -H 'Authorization: Bearer '$api \
  -d '{"name":"'$snapshot_name'","tags":["'$snapshot_tag'"]}' \
  "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots"
