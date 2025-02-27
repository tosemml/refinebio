#!/bin/sh

# Running this script will start an interactive python shell running
# within the context of a Docker container.
# By default the Docker container will be for the foreman project.

# This script should always run as if it were being called from
# the directory it lives in.
script_directory="$(
    cd "$(dirname "$0")" || exit
    pwd
)"
cd "$script_directory" || exit

# Import the functions in common.sh.
. ./common.sh

# We need access to all of the projects.
cd ..

print_description() {
    echo "Runs a management command in an image specified by -i and -s."
}

print_options() {
    echo "Options:"
    echo "    -h           Prints the help message"
    echo "    -i IMAGE     The image to be prepared. This must be specified."
    echo "    -s SERVICE   The service to seach for a dockerfile (workers, api, etc.)."
    echo "                 SERVICE defaults to the foreman."
    echo
    echo "NOTE: The arguments must be given in order (e.g. run_manage.sh -i \$IMAGE -s \$SERVICE)"
    echo
    echo "Examples:"
    echo "    Rebuild the elasticsearch index:"
    echo "    ./scripts/run_manage.sh -i api_local -s api search_index --rebuild -f"
}

if [ "$1" = "-h" ]; then
    print_description
    echo
    print_options
    exit 0
fi

if [ "$1" = "-i" ]; then
    shift
    if [ -z "$1" ]; then
        echo "Error: Missing argument for -i" >&2
        echo
        print_options >&2
        exit 1
    fi
    image=$1
    shift
else
    echo "Invalid option: $0" >&2
    echo "You must provide -i \$IMAGE, then optionally -s \$SERVICE" >&2
    echo
    print_options >&2
    exit 1
fi

if [ "$1" = "-s" ]; then
    shift
    if [ -z "$1" ]; then
        echo "Error: Missing argument for -s" >&2
        echo
        print_options >&2
        exit 1
    fi
    service=$1
    shift
else
    service="foreman"
fi

if [ -z "$SYSTEM_VERSION" ]; then
    SYSTEM_VERSION="$(get_branch_hash)"
fi

# Set up the data volume directory if it does not already exist.
volume_directory="$script_directory/../api/volume"
if [ ! -d "$volume_directory" ]; then
    mkdir "$volume_directory"
fi
chmod -R a+rwX "$volume_directory"

docker build \
    --build-arg DOCKERHUB_REPO="$DOCKERHUB_REPO" \
    --build-arg SYSTEM_VERSION="$SYSTEM_VERSION" \
    --file "$service/dockerfiles/Dockerfile.$image" \
    --platform linux/amd64 \
    --tag dr_shell \
    .

DB_HOST_IP=$(get_docker_db_ip_address)
ES_HOST_IP=$(get_docker_es_ip_address)

# Only run interactively if we are on a TTY.
if [ -t 1 ]; then
    INTERACTIVE="--interactive"
fi

# shellcheck disable=SC2086
docker run \
    --add-host=database:"$DB_HOST_IP" \
    --add-host=elasticsearch:"$ES_HOST_IP" \
    --env AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    --env AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    --env-file "$service/environments/local" \
    --platform linux/amd64 \
    --tty \
    --volume "$volume_directory":/home/user/data_store \
    --volume /tmp:/tmp \
    $INTERACTIVE \
    dr_shell \
    python3 manage.py "$@"
