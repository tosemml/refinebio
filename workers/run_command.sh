#!/bin/sh

# Script for executing Django management commands within a Docker container.

# Exit on failure
set -e

while getopts "i:" opt; do
    case $opt in
    i)
        IMAGE="$OPTARG"
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        exit 1
        ;;
    esac
done

if [ -z "$IMAGE" ]; then
    IMAGE="smasher"
else
    shift
    shift
fi

# This script should always run as if it were being called from
# the directory it lives in.
script_directory="$(
    cd "$(dirname "$0")" || exit
    pwd
)"
cd "$script_directory" || exit

# However in order to give Docker access to all the code we have to
# move up a level
cd ..

# Ensure that postgres is running
if ! [ "$(docker ps --filter name=drdb -q)" ]; then
    echo "You must start Postgres first with:" >&2
    echo "./scripts/run_postgres.sh" >&2
    exit 1
fi

volume_directory="$script_directory/volume"
if [ ! -d "$volume_directory" ]; then
    mkdir "$volume_directory"
fi
chmod -R a+rwX "$volume_directory"

. ./scripts/common.sh

DB_HOST_IP=$(get_docker_db_ip_address)

./scripts/prepare_image.sh -i "$IMAGE" -s workers

docker run \
    --add-host=database:"$DB_HOST_IP" \
    --env AWS_ACCESS_KEY_ID \
    --env AWS_SECRET_ACCESS_KEY \
    --env-file workers/environments/local \
    --interactive \
    --link drdb:postgres \
    --tty \
    --volume "$volume_directory":/home/user/data_store \
    "$DOCKERHUB_REPO/dr_$IMAGE" \
    bash -c "$@"
