#!/bin/bash

# run this script as root
if [ $(/usr/bin/id -u) -ne 0 ]; then
    echo "We recommend running this script as root"
    echo "Waiting 10s as confirmation"
    sleep 10s
else
    fix_permissions
fi
fix_permissions() {
    # chmod just in case
    # should be changed with untrusted users
    chmod +rwx ./setup/entrypoint.sh
}

cd src || echo "already in src"

finish() {
    echo "Now you can access kibana at http://10.2.160.10:16601/app/dashboards#/view/f3e771c0-eb19-11e6-be20-559646f8b9ba?_g=(filters:!(),refreshInterval:(pause:!f,value:1000),time:(from:now-24h%2Fh,to:now))"
    echo "Note that you should replace localhost with the ip of the machine where the docker containers are running if you are accessing from another machine"
    echo "Go check out the readme for future steps and setup your first services to monitor"
}

# take all args and set them instead of the questions:
ELASTIC_VERSION=$2
ELASTIC_PASSWORD=$3
KIBANA_SYSTEM_PASSWORD=$4
RABBITMQ_USERNAME=$5
RABBITMQ_PASSWORD=$6
RABBITMQ_HOST=$7
RABBITMQ_VIRTUAL_HOST=$8
RABBITMQ_QUEUE=$9
LOGGING_QUEUE=${10}

# not case senitive
if [[ "${1,,}" == "setup" ]]; then
    # just to tell  the user in what mode the script is running
    echo "Setting up for the first time"

    if [ $2 == "CD" ]; then
        echo "You are running in CD mode, skipping questions, we assume the .env is already good"
        sleep 10s
    else
        if [ -z "$ELASTIC_VERSION" ]; then
            echo "What version of elasticsearch do you want to use? (current latest is 8.12.2)"
            read ELASTIC_VERSION
        else
            echo "found ELASTIC_VERSION=$ELASTIC_VERSION"
        fi

        if [ -z "$ELASTIC_PASSWORD" ]; then
            echo "What password do you want to use for elasticsearch?"
            read -s ELASTIC_PASSWORD
        else
            echo "found ELASTIC_PASSWORD=$ELASTIC_PASSWORD"
        fi

        if [ -z "$KIBANA_SYSTEM_PASSWORD" ]; then
            echo "What password do you want to use for kibana?"
            read -s KIBANA_SYSTEM_PASSWORD
        else
            echo "found KIBANA_SYSTEM_PASSWORD=$KIBANA_SYSTEM_PASSWORD"
        fi

        if [ -z "$RABBITMQ_USERNAME" ]; then
            echo "What is your rabbitmq username?"
            read RABBITMQ_USERNAME
        else
            echo "found RABBITMQ_USERNAME=$RABBITMQ_USERNAME"
        fi

        if [ -z "$RABBITMQ_PASSWORD" ]; then
            echo "What is your rabbitmq password?"
            read -s RABBITMQ_PASSWORD
        else
            echo "found RABBITMQ_PASSWORD=$RABBITMQ_PASSWORD"
        fi

        if [ -z "$RABBITMQ_HOST" ]; then
            echo "What is your rabbitmq host?"
            read RABBITMQ_HOST
        else
            echo "found RABBITMQ_HOST=$RABBITMQ_HOST"
        fi

        if [ -z "$RABBITMQ_VIRTUAL_HOST" ]; then
            echo "What is your rabbitmq virtual host?"
            read RABBITMQ_VIRTUAL_HOST
        else
            echo "found RABBITMQ_VIRTUAL_HOST=$RABBITMQ_VIRTUAL_HOST"
        fi

        if [ -z "$RABBITMQ_QUEUE" ]; then
            echo "What is your rabbitmq queue where the heartbeats will be published?"
            read RABBITMQ_QUEUE
        else
            echo "found RABBITMQ_QUEUE=$RABBITMQ_QUEUE"
        fi

        if [ -z "$LOGGING_QUEUE" ]; then
            echo "What is your rabbitmq queue where the logs will be published?"
            read LOGGING_QUEUE
        else
            echo "found LOGGING_QUEUE=$LOGGING_QUEUE"
        fi

        # write everything into the file, so if the user cancels whil typing we don't have a half filled in .env
        echo "ELASTIC_VERSION=$ELASTIC_VERSION" >.env
        # for now you can't edit the admin username
        echo "ELASTIC_USERNAME='elastic'" >>.env
        echo "ELASTIC_PASSWORD='$ELASTIC_PASSWORD'" >>.env
        echo "KIBANA_SYSTEM_PASSWORD='$KIBANA_SYSTEM_PASSWORD'" >>.env
        echo "RABBITMQ_USERNAME='$RABBITMQ_USERNAME'" >>.env
        echo "RABBITMQ_PASSWORD='$RABBITMQ_PASSWORD'" >>.env
        echo "RABBITMQ_HOST='$RABBITMQ_HOST'" >>.env
        echo "RABBITMQ_VIRTUAL_HOST='$RABBITMQ_VIRTUAL_HOST'" >>.env
        echo "RABBITMQ_QUEUE='$RABBITMQ_QUEUE'" >>.env
        echo "LOGGING_QUEUE='$LOGGING_QUEUE'" >>.env
    fi

    # force recreate just in case the network is bugged (due to a previous version)
    docker compose up setup --force-recreate --build -d
    # better if we way, more clean but can actually be skipped (will be slower as the rest will constantly restart withouth this sleep)
    sleep 60s
    fix_permissions
    docker compose up setup-export --force-recreate --build -d

    # 1 restart for sealf healing
    docker compose up --build -d && docker compose down && docker compose up -d

    # we could remove setup containers & images but they use 0 resources, will be down on first down
    finish
fi

# if no args
if [ -z "$1" ]; then
    echo "Starting as normal"
    docker compose up -d

    finish
fi

if [[ "${1,,}" == "stop" || "${1,,}" == "down" ]]; then
    docker compose down

    echo "Stopped the environment"
fi

if [[ "${1,,}" == "--help" ]]; then
    echo "Usage: ./main.bash [option]"
    echo "Options:"
    echo "  setup: setup the environment for the first time"
    echo "  leave blank: start the environment"
    echo "  stop: stop the environment"
    echo "  --help: show this message"
    echo "  instead of relying on the questions you can pass the following arguments:"
    echo "  ./main.bash setup <ELASTIC_VERSION> <ELASTIC_PASSWORD> <KIBANA_SYSTEM_PASSWORD> <RABBITMQ_USERNAME> <RABBITMQ_PASSWORD> <RABBITMQ_HOST> <RABBITMQ_VIRTUAL_HOST> <RABBITMQ_QUEUE>"
fi
