#!/bin/sh

# Script for executing Django PyUnit tests within a Docker container.

# This script should always run as if it were being called from
# the directory it lives in.
script_directory="$(
    cd "$(dirname "$0")" || exit
    pwd
)"
cd "$script_directory" || exit

# However, in order to give Docker access to all the code we have to
# move up a level.
cd ..

./scripts/prepare_image.sh -i api_local -s api

. ./scripts/common.sh

DB_HOST_IP=$(get_docker_db_ip_address)
ES_HOST_IP=$(get_docker_es_ip_address)

docker run \
    --add-host=database:"$DB_HOST_IP" \
    --add-host=elasticsearch:"$ES_HOST_IP" \
    --env-file api/environments/local \
    --interactive \
    --publish 8000:8000 \
    --tty \
    "$DOCKERHUB_REPO/dr_api_local" \
    python3 manage.py runserver 0.0.0.0:8000 "$@"
