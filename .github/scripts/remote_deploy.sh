#!/bin/bash -e

# This script will deploy the Refinebio system using a dedicated AWS instance.
#   First it will use that instance to build up to date Docker images
#     and push them to Dockerhub.
#   Next it will use terraform to update our infrastructure and restart our services.
#   Finally it cleans up after itself.

# It has been written with the intention of being run from GitHub Actions as
#   part of our CI/CD process. It therefore assumes that the following
#   environment variables will be set:
#     - DEPLOY_IP_ADDRESS --  The IP address of the instance to run the deploy on.
#     - CI_TAG -- The tag that was pushed to GitHub to trigger the deploy.
#         Will be used as the version for the system and the tag for Docker images.
#     - DOCKER_ID -- The username that will be used to log into Dockerhub.
#     - DOCKER_PASSWD -- The password that will be used to log into Dockerhub.
#     - OPENSSL_KEY -- The OpenSSl key which will be used to decrypt the SSH key.
#     - AWS_ACCESS_KEY_ID -- The AWS key id to use when interacting with AWS.
#     - AWS_SECRET_ACCESS_KEY -- The AWS secret key to use when interacting with AWS.

echo "$INSTANCE_SSH_KEY" >infrastructure/data-refinery-key.pem
chmod 600 infrastructure/data-refinery-key.pem

run_on_deploy_box() {
    # shellcheck disable=SC2029
    ssh -o StrictHostKeyChecking=no \
        -o ServerAliveInterval=15 \
        -i infrastructure/data-refinery-key.pem \
        ubuntu@"${DEPLOY_IP_ADDRESS}" \
        "cd refinebio && $1"
}

# Create file containing local env vars that are needed for deploy.
rm -f env_vars
cat >>env_vars <<EOF
export CI_TAG='$CI_TAG'
export DOCKER_ID='$DOCKER_ID'
export DOCKER_PASSWD='$DOCKER_PASSWD'
export OPENSSL_KEY='$OPENSSL_KEY'
export AWS_ACCESS_KEY_ID='$AWS_ACCESS_KEY_ID'
export AWS_SECRET_ACCESS_KEY='$AWS_SECRET_ACCESS_KEY'
export TF_VAR_database_password='$DATABASE_PASSWORD'
export TF_VAR_django_secret_key='$DJANGO_SECRET_KEY'
export TF_VAR_raven_dsn='$RAVEN_DSN'
export TF_VAR_raven_dsn_api='$RAVEN_DSN_API'
export TF_VAR_engagementbot_webhook='$ENGAGEMENTBOT_WEBHOOK'
EOF

# And checkout the correct tag.
run_on_deploy_box "git fetch --all"
run_on_deploy_box "git checkout $CI_TAG"

# Verify that the tag has been signed by a trusted team member.
run_on_deploy_box "bash .github/scripts/verify_tag.sh $CI_TAG"

# Copy the necessary environment variables over.
scp -o StrictHostKeyChecking=no \
    -i infrastructure/data-refinery-key.pem \
    -r env_vars ubuntu@"$DEPLOY_IP_ADDRESS":refinebio/env_vars

# Along with the ssh key iself, which the deploy script will use.
scp -o StrictHostKeyChecking=no \
    -i infrastructure/data-refinery-key.pem \
    -r infrastructure/data-refinery-key.pem ubuntu@"$DEPLOY_IP_ADDRESS":refinebio/infrastructure/data-refinery-key.pem

echo "Building new images"
# Output to the docker update log.
run_on_deploy_box "sudo touch /var/log/docker_update_$CI_TAG.log"
run_on_deploy_box "sudo chown ubuntu:ubuntu /var/log/docker_update_$CI_TAG.log"
run_on_deploy_box ". env_vars && echo -e '######\nBuilding new images for $CI_TAG\n######' 2>&1 | tee -a /var/log/docker_update_$CI_TAG.log"
run_on_deploy_box ". env_vars && ./.github/scripts/update_docker_images.sh 2>&1 | tee -a /var/log/docker_update_$CI_TAG.log"
run_on_deploy_box ". env_vars && echo -e '######\nFinished building new images for $CI_TAG\n######' 2>&1 | tee -a /var/log/docker_update_$CI_TAG.log"

# Load docker_image_exists function and $ALL_IMAGES.
# shellcheck disable=1091
. ./scripts/common.sh

if [[ "$BRANCH" == "master" ]]; then
    DOCKERHUB_REPO=ccdl
elif [[ "$BRANCH" == "dev" ]]; then
    DOCKERHUB_REPO=ccdlstaging
else
    echo "Why in the world was remote_deploy.sh called from a branch other than dev or master?!"
    exit 1
fi

# It's somehow possible for Docker to sometimes not successfully push
# an image but yet still exit successfully. See:
# https://github.com/AlexsLemonade/refinebio/issues/784
# Since it's not clear how that happened, the safest thing is to add
# an explicit check that the Docker images were successfully updated.
for image in $ALL_IMAGES; do
    image_name="$DOCKERHUB_REPO/dr_$image"
    if ! docker_image_exists "$image_name" "$CI_TAG"; then
        echo "Docker image $image_name:$CI_TAG doesn't exist after running update_docker_images.sh!"
        echo "This is generally caused by a temporary error, please try the 'Rerun workflow' button."
        exit 1
    fi
done

# Notify CircleCI that the images have been built.
echo "Finished building new images, running run_terraform.sh."

run_on_deploy_box "sudo touch /var/log/deploy_$CI_TAG.log"
run_on_deploy_box "sudo chown ubuntu:ubuntu /var/log/deploy_$CI_TAG.log"
run_on_deploy_box ". env_vars && echo -e '######\nStarting new deploy for $CI_TAG\n######' >> /var/log/deploy_$CI_TAG.log 2>&1"
run_on_deploy_box "sudo .github/scripts/update_ca_certificates.sh >> /var/log/deploy_$CI_TAG.log 2>&1"

# This should never be logged to Github Actions in case it exposes any secrets as terraform output.
run_on_deploy_box ". env_vars && .github/scripts/run_terraform.sh >> /var/log/deploy_$CI_TAG.log 2>&1"

run_on_deploy_box ". env_vars && echo -e '######\nDeploying $CI_TAG finished!\n######' >> /var/log/deploy_$CI_TAG.log 2>&1"

.github/scripts/slackpost_deploy.sh robots deploybot

if [[ "$BRANCH" == "dev" ]]; then
    run_on_deploy_box ". env_vars && ./foreman/run_end_to_end_tests.sh"
    .github/scripts/slackpost_end_to_end.sh robots deploybot
fi

# Don't leave secrets lying around.
run_on_deploy_box "git clean -f"
