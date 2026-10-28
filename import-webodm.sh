#!/bin/bash
# Sourced by webui.sh. Imports the database of a WebODM installation into this one.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	echo "Run ./webui.sh import-webodm"
	exit 1
fi

import_webodm_container="webui-import-webodm-db"
import_webodm_image="webodm/webodm_db"
import_webodm_new_volume=""

# Git Bash rewrites arguments that look like POSIX paths (/data/PG_VERSION,
# /c/dir:/data) into Windows paths before docker sees them. MSYS_NO_PATHCONV
# turns that off for one command and is ignored everywhere else.
import_webodm_docker_run(){
	MSYS_NO_PATHCONV=1 docker run "$@"
}

import_webodm_db_image(){
	$docker_compose -f docker-compose.yml config --images db 2> /dev/null
}

# WebODM keeps a Postgres 9.5 cluster at the root of its database directory.
# Postgres 18 keeps its cluster in 18/docker, so a PG_VERSION file at the root
# can only be WebODM's. The directory belongs to the postgres user with mode
# 0700, so the check runs in a container.
import_webodm_is_webodm_dir(){
	[ -d "$1" ] && import_webodm_docker_run --rm -v "$1:/data:ro" --entrypoint test "$(import_webodm_db_image)" -f /data/PG_VERSION > /dev/null 2>&1
}

import_webodm_project(){
	echo "${COMPOSE_PROJECT_NAME:-$(basename "$__dirname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g; s/^[-_]*//')}"
}

import_webodm_dir_flags(){
	[[ $WO_DB_DIR = /* ]] && echo -n " --db-dir $WO_DB_DIR"
	[[ $WO_MEDIA_DIR = /* ]] && echo -n " --media-dir $WO_MEDIA_DIR"
	return 0
}

import_webodm_start_hint(){
	echo "Start OpenDroneMap WebUI with: $0 start$(import_webodm_dir_flags)"
}

# Two Postgres servers on one data directory corrupt it
import_webodm_check_webodm_stopped(){
	if docker ps --format '{{.Image}}' | grep -q '^webodm/webodm_db'; then
		echo -e "\033[91mWebODM is running. Stop it first with webodm.sh stop\033[39m"
		exit 1
	fi
}

# Called by start. A WebODM database in a docker volume is offered for import
# until this installation's own volume exists. Postgres 18 cannot use a WebODM
# database directory, so a start on one is refused with the import command.
import_webodm_offer(){
	local answer
	if [[ $WO_DB_DIR = /* ]]; then
		if import_webodm_is_webodm_dir "$WO_DB_DIR"; then
			echo -e "\033[91mPostgres 18 cannot start in $WO_DB_DIR: it holds a WebODM database.\033[39m"
			echo "To keep your WebODM projects, tasks and users, run: $0 import-webodm --webodm-db-dir $WO_DB_DIR --db-dir <new directory>"
			echo "Leave out --db-dir to import into a docker volume instead."
			echo "To start with an empty installation, pass --db-dir pointing at an empty directory."
			exit 1
		fi
		return
	fi
	if ! docker volume inspect webodm_dbdata > /dev/null 2>&1 || docker volume inspect "$(import_webodm_project)_dbdata" > /dev/null 2>&1; then
		return
	fi
	import_webodm_check_webodm_stopped
	if [[ $skip_import = true ]]; then
		return
	fi
	if [[ $detached = true ]] || [ ! -t 0 ]; then
		echo -e "\033[91mFound a WebODM database (docker volume webodm_dbdata).\033[39m"
		echo "To keep your WebODM projects, tasks and users, run: $0 import-webodm$(import_webodm_dir_flags)"
		echo "To start with an empty installation instead, run: $0 start --skip-import"
		exit 1
	fi
	read -r -p "Found a WebODM database (docker volume webodm_dbdata). Import it? [Y/n] " answer
	if [[ $answer =~ ^[Nn] ]]; then
		echo "Starting with an empty installation."
	else
		import_webodm
	fi
}

# Run a command showing its output only if it fails
import_webodm_quiet(){
	local output
	if ! output=$("$@" 2>&1); then
		echo "$output"
		return 1
	fi
}

import_webodm_stop_servers(){
	docker rm -f "$import_webodm_container" > /dev/null 2>&1 || true
	$docker_compose -f docker-compose.yml rm -sf db > /dev/null 2>&1 || true
}

# Exit trap while the import runs. The database volume this run created goes
# too, so the next start offers the import again.
import_webodm_failed(){
	trap - EXIT
	import_webodm_stop_servers
	if [ -n "$import_webodm_new_volume" ]; then
		docker volume rm "$import_webodm_new_volume" > /dev/null 2>&1 || true
	fi
	echo -e "\033[91mImport failed. Your WebODM data is unchanged.\033[39m"
	exit 1
}

# Copies the WebODM database (docker volume webodm_dbdata, or the directory
# given with --webodm-db-dir) into this installation's database (its docker
# volume, or the directory given with --db-dir). WebODM's media volume is
# reused in place. Nothing of WebODM's is modified.
import_webodm(){
	local source target network output imported media_volume

	if [ -n "$WO_WEBODM_DB_DIR" ]; then
		source="$WO_WEBODM_DB_DIR"
		if ! import_webodm_is_webodm_dir "$source"; then
			echo -e "\033[91mNo WebODM database in $source.\033[39m"
			exit 1
		fi
	elif docker volume inspect webodm_dbdata > /dev/null 2>&1; then
		source="webodm_dbdata"
	else
		echo -e "\033[91mNo WebODM database found (docker volume webodm_dbdata). For a WebODM started with --db-dir, pass --webodm-db-dir.\033[39m"
		exit 1
	fi

	if [[ $WO_DB_DIR = /* ]]; then
		if [ "$WO_DB_DIR" = "$source" ] || import_webodm_is_webodm_dir "$WO_DB_DIR"; then
			echo -e "\033[91m$WO_DB_DIR holds a WebODM database. Pass --db-dir pointing at a new directory.\033[39m"
			exit 1
		fi
		target="$WO_DB_DIR"
	else
		target="docker volume $(import_webodm_project)_dbdata"
		if ! docker volume inspect "$(import_webodm_project)_dbdata" > /dev/null 2>&1; then
			import_webodm_new_volume="$(import_webodm_project)_dbdata"
		fi
	fi
	import_webodm_check_webodm_stopped

	if [[ $WO_MEDIA_DIR != /* ]] && docker volume inspect webodm_appmedia > /dev/null 2>&1; then
		media_volume="webodm_appmedia"
		export WO_MEDIA_VOLUME="$media_volume"
		export WO_MEDIA_EXTERNAL=true
	fi

	echo "Importing from WebODM"
	echo "================================"
	echo "WebODM database: $source"
	echo "OpenDroneMap WebUI database: $target"
	if [ -n "$media_volume" ]; then
		echo "WebODM media: docker volume $media_volume (used in place)"
	fi
	echo "================================"

	trap import_webodm_failed EXIT
	docker rm -f "$import_webodm_container" > /dev/null 2>&1 || true
	import_webodm_quiet $docker_compose -f docker-compose.yml up --no-start db
	network=$(docker inspect webui-db --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{end}}')

	echo "Starting the WebODM database..."
	import_webodm_quiet import_webodm_docker_run -d --name "$import_webodm_container" --network "$network" -v "$source:/var/lib/postgresql/data" "$import_webodm_image"

	echo "Starting the OpenDroneMap WebUI database..."
	import_webodm_quiet $docker_compose -f docker-compose.yml up -d db

	echo "Copying the database..."
	output=$($docker_compose -f docker-compose.yml run --rm --no-deps --entrypoint python webapp manage.py importwebodm --host "$import_webodm_container" 2>&1) && imported=true || imported=false
	echo "$output" | grep -vE '^\s*$|pkg_resources|Generated secret|Container .* (Creating|Created)|mount of type' || true
	if [[ $imported != true ]]; then
		exit 1
	fi

	trap - EXIT
	import_webodm_stop_servers
	if [ -n "$media_volume" ] && ! grep -q '^WO_MEDIA_VOLUME=' "${__dirname}/.env"; then
		printf 'WO_MEDIA_VOLUME=%s\nWO_MEDIA_EXTERNAL=true\n' "$media_volume" >> "${__dirname}/.env"
	fi
	echo -e "\033[1mDone!\033[0m WebODM data imported."
}
