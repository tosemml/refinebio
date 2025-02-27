#!/bin/bash -e

# This script should always run as if it were being called from
# the directory it lives in.
script_directory="$(
    cd "$(dirname "$0")" || exit
    pwd
)"
cd "$script_directory" || exit

print_description() {
    echo 'This script can be used to destroy an infrastructure stack that was created with deploy.sh.'
}

print_options() {
    echo 'This script accepts the following arguments: -e, -u, -d, and -h.'
    echo 'Neither -e, -u or -d is optional unless TF_VAR_stage, TF_VAR_user,'
    echo 'or TF_VAR_region is set, respectively.'
    echo '-h prints this help message and exits.'
    echo '-e specifies the environment you would like to destroy.'
    echo '-u specifies the username you used to spin up the stack.'
    echo '-d specifies the region of the stack to destroy.'
    echo 'All arguments are needed to determine which stack to destroy.'
}

while getopts ":e:u:d:h" opt; do
    case $opt in
    e)
        export env=$OPTARG
        export TF_VAR_stage=$OPTARG
        ;;
    u)
        export TF_VAR_user=$OPTARG
        ;;
    d)
        export TF_VAR_region=$OPTARG
        ;;
    h)
        print_description
        echo
        print_options
        exit 0
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        print_options >&2
        exit 1
        ;;
    :)
        echo "Option -$OPTARG requires an argument." >&2
        print_options >&2
        exit 1
        ;;
    esac
done

if [[ $TF_VAR_stage != "dev" && $TF_VAR_stage != "staging" && $TF_VAR_stage != "prod" ]]; then
    echo 'Error: must specify environment as either "dev", "staging", or "prod" with -e or TF_VAR_enviroment.'
    exit 1
fi

if [[ -z $TF_VAR_user ]]; then
    echo 'Error: must specify the username by either providing the -u argument or setting TF_VAR_user.'
    exit 1
fi

if [[ -z $TF_VAR_region ]]; then
    echo 'Error: must specify region by either providing the -d argument or setting TF_VAR_region.'
    exit 1
fi

terraform destroy -var-file="environments/$env.tfvars"

# These aren't managed by terraform so we have to deregistr them manually.
export USER="$TF_VAR_user"
export STAGE="$TF_VAR_stage"
export AWS_REGION="$TF_VAR_region"
python3 deregister_batch_job_definitions.py
