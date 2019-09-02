# snapshot-volume-digitalocean
This is sample script to delete and create the snapshot of the volume / block storage that provided by Digital Ocean.The purpose of this script is to help user of DigitalOcean doing their block storage / volume backup automatically. This script can be run with cronjob and running with daily, weekly, or monthly basis depend on your need. 

## Predefined
You need to define first some variable like apikey, snapshot_name, snapshot_tags, and volume_name to use this script. To get your api key you can follow this link https://www.digitalocean.com/docs/api/create-personal-access-token/. 
