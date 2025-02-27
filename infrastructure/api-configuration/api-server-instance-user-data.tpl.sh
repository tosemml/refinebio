#!/bin/bash

# This is a template for the instance-user-data.sh script for the API Server.
# For more information on instance-user-data.sh scripts, see:
# https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html

# This script will be formatted by Terraform, which will read files from the
# project into terraform variables, and then template them into the following
# script. These will then be written out to files so that they can be used
# locally. This means that any variable referenced using `{}` is NOT a shell
# variable, it is a template variable for Terraform to fill in. DO NOT treat
# them as normal shell variables.

# Change to home directory of the default user
cd /home/ubuntu || exit

# Install and configure Nginx.
cat <<"EOF" >nginx.conf
${nginx_config}
EOF
apt-get update -y
apt-get install nginx awscli zip -y
cp nginx.conf /etc/nginx/nginx.conf
service nginx restart

if [[ "${stage}" == "staging" || "${stage}" == "prod" ]]; then
    # Check here for the cert in S3, if present install, if not run certbot.
    if [[ $(aws s3 ls "${data_refinery_cert_bucket}" | wc -l) == "0" ]]; then
        # Create and install SSL Certificate for the API.
        # Only necessary on staging and prod.
        # We cannot use ACM for this because *.bio is not a Top Level Domain that Route53 supports.
        snap install core
        snap refresh core
        snap install --classic certbot
        apt-get update
        apt-get install -y python-certbot-nginx

        # Temporary to see what this outputs
        curl 'http://api.refine.bio'
        # The certbot challenge cannot be completed until the aws_lb_target_group_attachment resources are created.
        sleep 300
        # Temporary to see what this outputs
        curl 'http://api.refine.bio'

        # g3w4k4t5n3s7p7v8@alexslemonade.slack.com is the email address we
        # have configured to forward mail to the #teamcontact channel in
        # slack. Certbot will use it for "important account
        # notifications".
        # In the future, if we ever hit the 5-deploy-a-week limit, changing one of these lines to:
        # certbot --nginx -d api.staging.refine.bio -d api2.staging.refine.bio -n --agree-tos --redirect -m g3w4k4t5n3s7p7v8@alexslemonade.slack.com
        # will circumvent certbot's limit because the 5-a-week limit only applies to the
        # "same set of domains", so by changing that set we get to use the 20-a-week limit.
        if [[ "${stage}" == "staging" ]]; then
            certbot --nginx -d api.staging.refine.bio -n --agree-tos --redirect -m g3w4k4t5n3s7p7v8@alexslemonade.slack.com
        elif [[ "${stage}" == "prod" ]]; then
            certbot --nginx -d api.refine.bio -n --agree-tos --redirect -m g3w4k4t5n3s7p7v8@alexslemonade.slack.com
        fi

        # Add the nginx.conf file that certbot setup to the zip dir.
        cp /etc/nginx/nginx.conf /etc/letsencrypt/

        cd /etc/letsencrypt/ || exit
        sudo zip -r ../letsencryptdir.zip "../$(basename "$PWD")"

        # And then cleanup the extra copy.
        rm /etc/letsencrypt/nginx.conf

        cd - || exit
        mv /etc/letsencryptdir.zip .
        aws s3 cp letsencryptdir.zip "s3://${data_refinery_cert_bucket}/"
        rm letsencryptdir.zip
    else
        zip_filename=$(aws s3 ls "${data_refinery_cert_bucket}" | head -1 | awk '{print $4}')
        aws s3 cp "s3://${data_refinery_cert_bucket}/$zip_filename" letsencryptdir.zip
        unzip letsencryptdir.zip -d /etc/
        mv /etc/letsencrypt/nginx.conf /etc/nginx/
        service nginx restart
    fi
fi

# Install, configure and launch our CloudWatch Logs agent
cat <<EOF >awslogs.conf
[general]
state_file = /var/lib/awslogs/agent-state

[/tmp/error.log]
file = /tmp/error.log
log_group_name = ${log_group}
log_stream_name = log-stream-api-nginx-error-${user}-${stage}

[/tmp/access.log]
file = /tmp/access.log
log_group_name = ${log_group}
log_stream_name = log-stream-api-nginx-access-${user}-${stage}

EOF

mkdir /var/lib/awslogs
wget https://s3.amazonaws.com/aws-cloudwatch/downloads/latest/awslogs-agent-setup.py
python3.5 ./awslogs-agent-setup.py --region "${region}" --non-interactive --configfile awslogs.conf
# Rotate the logs, delete after 3 days.
echo "
/tmp/error.log {
    missingok
    notifempty
    compress
    size 20k
    daily
    maxage 3
}" >>/etc/logrotate.conf
echo "
/tmp/access.log {
    missingok
    notifempty
    compress
    size 20k
    daily
    maxage 3
}" >>/etc/logrotate.conf

# Install our environment variables
cat <<"EOF" >environment
${api_environment}
EOF

chown -R ubuntu /home/ubuntu

STATIC_VOLUMES=/tmp/volumes_static
mkdir -p /tmp/volumes_static
chmod a+rwx /tmp/volumes_static

# Pull the API image.
docker pull "${dockerhub_repo}/${api_docker_image}"

# These database values are created after TF
# is run, so we have to pass them in programatically
docker run \
    --detach \
    --env DATABASE_HOST="${database_host}" \
    --env DATABASE_NAME="${database_name}" \
    --env DATABASE_PASSWORD="${database_password}" \
    --env DATABASE_USER="${database_user}" \
    --env ELASTICSEARCH_HOST="${elasticsearch_host}" \
    --env ELASTICSEARCH_PORT="${elasticsearch_port}" \
    --env-file environment \
    --interactive \
    --log-driver awslogs \
    --log-opt awslogs-group="${log_group}" \
    --log-opt awslogs-region="${region}" \
    --log-opt awslogs-stream="${log_stream}" \
    --name dr_api \
    --tty \
    --volume "$STATIC_VOLUMES":/tmp/www/static \
    --publish 8081:8081 \
    "${dockerhub_repo}/${api_docker_image}" \
    /bin/sh -c "/home/user/collect_and_run_uwsgi.sh"

# Nuke and rebuild the search index. It shouldn't take too long.
sleep 30
docker exec dr_api python3 manage.py search_index --delete -f
docker exec dr_api python3 manage.py search_index --rebuild -f
docker exec dr_api python3 manage.py search_index --populate -f

# Let's use this instance to call the populate command every twenty minutes.
crontab -l >tempcron
# echo new cron into cron file
# TODO: stop logging this to api_cron.log once we figure out why it
# hasn't been working.
echo -e "SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n*/20 * * * * docker exec dr_api python3 manage.py update_es_index >> /var/log/api_cron.log 2>&1" >>tempcron
# Post a summary of downloads every Monday at 12:00 UTC
echo -e "SHELL=/bin/bash\nPATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin\n0 12 * * MON docker exec dr_api python3 manage.py post_downloads_summary >> /var/log/api_cron.log 2>&1" >>tempcron
# install new cron file
crontab tempcron
rm tempcron

# Don't leave secrets lying around.
rm -f environment

# Delete the cloudinit and syslog in production.
export STAGE=${stage}
if [[ $STAGE = *"prod"* ]]; then
    rm /var/log/cloud-init.log
    rm /var/log/cloud-init-output.log
    rm /var/log/syslog
fi
