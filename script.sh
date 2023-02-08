#!/bin/bash

addHostsToConfig() {
    DNS_IP_LIST=$1
    if [[ "$DNS_IP_LIST" == "" ]]; then
        echo "[!] Error! 'DNS:IP;' expected!"
        exit 1
    fi

    filename="/etc/gitlab-runner/config.toml"
    NEW_TEXT="$(cat $filename)"
    NEWLINE=$'\n'
    HOST_ALIAS_HEADER="    [[runners.kubernetes.host_aliases]]"
    IFS=";"
    for DNS_IP in $DNS_IP_LIST; do
        LAST_IP_ENTRY="$(echo -n $DNS_IP | cut -d ':' -f 1)"
        HOSTS="$(echo -n $DNS_IP | cut -d ':' -f 2)"
        IFS=' '
        LAST_HOST="$(echo ${HOSTS##* })"
        NEW_TEXT="${NEW_TEXT}${NEWLINE}${HOST_ALIAS_HEADER}"
        HOSTNAMES="["
        for DNS in $HOSTS; do
            HOSTNAMES="${HOSTNAMES}\"${DNS}\""
            if [[ "$DNS" != "$LAST_HOST" ]]; then
                HOSTNAMES="${HOSTNAMES}, "
            fi
        done
        HOSTNAMES="${HOSTNAMES}]"
        IFS=";"
        NEW_TEXT="${NEW_TEXT}${NEWLINE}      ip = \"${LAST_IP_ENTRY}\"${NEWLINE}      hostnames = ${HOSTNAMES}"
    done
    echo $NEW_TEXT > /etc/gitlab-runner/config.toml
}

RETRIES=0
while [[ "$(curl --connect-timeout 15 --max-time 30 -Ls -o /dev/null -w ''%{http_code}'' ${GITLAB_HOST})" != "200" ]]; do
    echo "[*] Checking connection with ${GITLAB_HOST}"
    ((RETRIES=RETRIES+=1))
    if [[ $RETRIES -eq 3 ]]; then
        echo "Could not connect to ${GITLAB_HOST}!"
        exit 1
    fi
    sleep 5
done
gitlab-runner register --non-interactive --url="${GITLAB_HOST}" --registration-token="${REGISTRATION_TOKEN}" --executor="${EXECUTOR}" --description="${DESCRIPTION}" --tag-list="${TAG}"

if [ "${EXECUTOR}" == "kubernetes" ]; then
    sed -i "s/namespace = \"\"/namespace = \"${NAMESPACE}\"/" /etc/gitlab-runner/config.toml
    if [[ "$DNS_IP_LIST" != "" ]]; then
        addHostsToConfig "$DNS_IP_LIST"
    fi
fi


/usr/bin/dumb-init /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner
