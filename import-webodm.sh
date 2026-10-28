#!/bin/bash
# Sourced by webui.sh. Imports the database of a WebODM installation into this one.
if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
	echo "Run ./webui.sh import-webodm"
	exit 1
fi

import_webodm_db_image(){
	$docker_compose -f docker-compose.yml config --images db 2> /dev/null
}

# WebODM stores a Postgres 9.5 cluster at the root of its database directory or
# volume. Postgres 18 keeps its cluster in 18/docker, so a PG_VERSION file at the
# root of WO_DB_DIR can only be WebODM's. The directory belongs to the postgres
# user with mode 0700, so the check runs in a container.
import_webodm_layout(){
	case "$WO_DB_DIR" in
		/*)
			if [ -d "$WO_DB_DIR" ] && docker run --rm -v "$WO_DB_DIR:/data:ro" --entrypoint test "$(import_webodm_db_image)" -f /data/PG_VERSION > /dev/null 2>&1; then
				echo path
			fi
			;;
		*) docker volume inspect webodm_dbdata > /dev/null 2>&1 && echo volume ;;
	esac
	return 0
}

import_webodm_project(){
	echo "${COMPOSE_PROJECT_NAME:-$(basename "$__dirname" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]//g; s/^[-_]*//')}"
}

import_webodm_where(){
	if [ "$1" = "path" ]; then
		echo "in $WO_DB_DIR"
	else
		echo "(docker volume webodm_dbdata)"
	fi
}

import_webodm_hint(){
	echo -n "To keep your WebODM projects, tasks and users, run: $0 import-webodm"
	[[ $WO_DB_DIR = /* ]] && echo -n " --db-dir $WO_DB_DIR"
	[[ $WO_MEDIA_DIR = /* ]] && echo -n " --media-dir $WO_MEDIA_DIR"
	echo
	if [ "$1" = "path" ]; then
		echo "To start with an empty installation instead, pass --db-dir pointing at an empty directory."
	else
		echo "To start with an empty installation instead, run: $0 start --skip-import"
	fi
}

import_webodm_refuse_dir(){
	echo -e "\033[91mPostgres 18 cannot start in $WO_DB_DIR while it holds a WebODM database.\033[39m"
	import_webodm_hint path
	exit 1
}

import_webodm_check_webodm_stopped(){
	if docker ps --format '{{.Image}}' | grep -q '^webodm/webodm_db'; then
		echo -e "\033[91mWebODM is running. Stop it first with webodm.sh stop\033[39m"
		exit 1
	fi
}

import_webodm_container="webui-import-webodm-db"
import_webodm_image="webodm/webodm_db"
import_webodm_tmp=""

# Runs inside a container with WO_DB_DIR mounted at /data after a successful
# import: the 9.5 cluster moves into 9.5/ and the new cluster into 18/. WebODM
# left the directory itself with mode 0700, which the Postgres 18 user cannot
# traverse.
import_webodm_swap='
cd /data || exit 1
rmdir 18/docker 18 2> /dev/null
mkdir 9.5 && chmod 755 . || exit 1
for f in *; do
	case "$f" in
		9.5|webui-import) ;;
		*) mv "$f" 9.5/ || exit 1 ;;
	esac
done
mv webui-import/18 18 && rmdir webui-import
'

# Run a command showing its output only if it fails
import_webodm_quiet(){
	local output
	if ! output=$("$@" 2>&1); then
		echo "$output"
		import_webodm_cleanup
		exit 1
	fi
}

import_webodm_cleanup(){
	docker rm -f "$import_webodm_container" > /dev/null 2>&1 || true
	$docker_compose -f docker-compose.yml rm -sf db > /dev/null 2>&1
	if [ -n "$import_webodm_tmp" ]; then
		docker run --rm -v "$WO_DB_DIR:/data" --entrypoint rm "$(import_webodm_db_image)" -rf /data/webui-import > /dev/null 2>&1 || true
	fi
}

# Called by start: offer to import when a WebODM database exists where this installation has never run
import_webodm_offer(){
	local layout answer
	layout=$(import_webodm_layout)
	if [ -z "$layout" ]; then
		return
	fi
	if [ "$layout" = "volume" ] && docker volume inspect "$(import_webodm_project)_dbdata" > /dev/null 2>&1; then
		return
	fi
	import_webodm_check_webodm_stopped
	if [[ $skip_import = true ]]; then
		[ "$layout" = "volume" ] && return
		import_webodm_refuse_dir
	fi
	if [[ $detached = true ]] || [ ! -t 0 ]; then
		echo -e "\033[91mFound a WebODM database $(import_webodm_where "$layout").\033[39m"
		import_webodm_hint "$layout"
		exit 1
	fi
	read -r -p "Found a WebODM database $(import_webodm_where "$layout"). Import it? [Y/n] " answer
	if [[ $answer =~ ^[Nn] ]]; then
		if [ "$layout" = "volume" ]; then
			echo "Starting with an empty installation."
		else
			import_webodm_refuse_dir
		fi
	else
		import_webodm "$layout"
	fi
}

import_webodm(){
	local layout="${1:-$(import_webodm_layout)}"
	local src_db target_db_dir media_volume network output imported

	if [ -z "$layout" ]; then
		echo -e "\033[91mNo WebODM database found (docker volume webodm_dbdata, or Postgres data in $WO_DB_DIR).\033[39m"
		exit 1
	fi
	import_webodm_check_webodm_stopped

	if [ "$layout" = "volume" ]; then
		src_db="webodm_dbdata"
		target_db_dir="$WO_DB_DIR"
	else
		src_db="$WO_DB_DIR"
		target_db_dir="$WO_DB_DIR/webui-import"
		import_webodm_tmp="$target_db_dir"
	fi
	if [[ $WO_MEDIA_DIR != /* ]] && docker volume inspect webodm_appmedia > /dev/null 2>&1; then
		media_volume="webodm_appmedia"
		export WO_MEDIA_VOLUME="$media_volume"
		export WO_MEDIA_EXTERNAL=true
	fi

	echo "Importing from WebODM"
	echo "================================"
	echo "WebODM database: $src_db"
	if [ -n "$media_volume" ]; then
		echo "WebODM media: docker volume $media_volume (used in place)"
	fi
	echo "================================"

	# The WebODM database starts first: its entrypoint chowns everything under
	# its data directory, which in the path layout includes the new cluster.
	docker rm -f "$import_webodm_container" > /dev/null 2>&1 || true
	import_webodm_quiet env WO_DB_DIR="$target_db_dir" $docker_compose -f docker-compose.yml up --no-start db
	network=$(docker inspect webui-db --format '{{range $name, $_ := .NetworkSettings.Networks}}{{$name}}{{end}}')

	echo "Starting the WebODM database..."
	import_webodm_quiet docker run -d --name "$import_webodm_container" --network "$network" -v "$src_db:/var/lib/postgresql/data" "$import_webodm_image"

	echo "Starting the OpenDroneMap WebUI database..."
	import_webodm_quiet env WO_DB_DIR="$target_db_dir" $docker_compose -f docker-compose.yml up -d db

	echo "Copying the database..."
	if output=$($docker_compose -f docker-compose.yml run --rm --no-deps --entrypoint python webapp manage.py importwebodm --host "$import_webodm_container" 2>&1); then
		imported=true
	else
		imported=false
	fi
	echo "$output" | grep -vE '^\s*$|pkg_resources|Generated secret|Container .* (Creating|Created)|mount of type' || true
	if [[ $imported = true ]]; then
		import_webodm_tmp=""
	fi
	import_webodm_cleanup
	if [[ $imported != true ]]; then
		echo -e "\033[91mImport failed. Your WebODM data is unchanged.\033[39m"
		exit 1
	fi

	if [ "$layout" = "path" ]; then
		echo "Moving the WebODM database to $WO_DB_DIR/9.5..."
		import_webodm_quiet docker run --rm -v "$WO_DB_DIR:/data" --entrypoint sh "$(import_webodm_db_image)" -c "$import_webodm_swap"
	fi
	if [ -n "$media_volume" ] && ! grep -q '^WO_MEDIA_VOLUME=' "${__dirname}/.env"; then
		printf 'WO_MEDIA_VOLUME=%s\nWO_MEDIA_EXTERNAL=true\n' "$media_volume" >> "${__dirname}/.env"
	fi

	echo -e "\033[1mDone!\033[0m WebODM data imported."
}
