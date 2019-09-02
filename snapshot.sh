#!/bin/bash

api=""
now=$(date +"%Y-%m-%d")
snapshot_name=""
snapshot_tags=""
volume_name=""

## check value of predefined variable
if [ "$api" == "" ] || [ "$snapshot_name" == "" ] || [ "$snapshot_tags" == "" ] || [ "$volume_name" == "" ];
then
    echo "Please check your variable value"
    exit 1
fi

## get volume id
volume_id=$(curl -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes?name=$volume_name" | \
jq -r '.volumes[].id')

# get snaphost id that would deleted
snapshot_id=$(curl -X GET \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots?page=1&per_page=1" | \
jq '.snapshots | map(select((.created_at < "'$now'" and .name == "'$snapshot_name'")))' | \
jq -r '.[].id')

## delete snapshot
curl -X DELETE \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    "https://api.digitalocean.com/v2/snapshots/$snapshot_id"

## create new snapshot today
curl -X POST \
    -H 'Content-Type: application/json' \
    -H 'Authorization: Bearer '$api \
    -d '{"name":"'$snapshot_name'","tags":["'$snapshot_tags'"]}' \
    "https://api.digitalocean.com/v2/volumes/$volume_id/snapshots"