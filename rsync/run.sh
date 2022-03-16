#!/usr/bin/env bashio
# shellcheck shell=bash

set -e

PRIVATE_KEY_FILE=$(bashio::config 'private_key_file')
if [ ! -f "$PRIVATE_KEY_FILE" ]; then
	bashio::log.info 'Generate keypair'

	mkdir -p "$(dirname "$PRIVATE_KEY_FILE")"
	ssh-keygen -t rsa -b 4096 -f "$PRIVATE_KEY_FILE" -N ''

	bashio::log.info "Generated key-pair in $PRIVATE_KEY_FILE"
else
	bashio::log.info "Use private key from $PRIVATE_KEY_FILE"
fi

HOST=$(bashio::config 'remote_host')
USERNAME=$(bashio::config 'username')
FOLDERS=$(bashio::config 'folders')
REMOTE_FOLDER=$(bashio::config 'remote_folder')

if bashio::config.has_value 'remote_port'; then
	PORT=$(bashio::config 'remote_port')
	bashio::log.info "Use port $PORT"
else
	PORT=22
fi

if bashio::config.has_value 'options'; then
	OPTIONS=$(bashio::config 'options')
	bashio::log.info "Use options $OPTIONS"
else
	OPTIONS='-archive --recursive --compress --delete --prune-empty-dirs'
fi

error_count=0

for folder in $FOLDERS; do

	bashio::log.info "Sync $folder -> ${REMOTE_FOLDER}"
	# shellcheck disable=SC2086
	if ! rsync ${OPTIONS} \
	-e "ssh -p ${PORT} -i ${PRIVATE_KEY_FILE} -oStrictHostKeyChecking=no" \
	"$folder" "${USERNAME}@${HOST}:${REMOTE_FOLDER}"
	then
		error_count=$(expr $error_count + 1)
	fi
done

if [ "$error_count" -eq 0 ]; then
	curl -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
	-H "Content-Type: application/json" \
	http://supervisor/core/api/events/rsync_finished
else
	curl -X POST -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
	-H "Content-Type: application/json" \
	http://supervisor/core/api/events/rsync_failed
fi

bashio::log.info "Synced all folders"