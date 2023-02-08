#!/bin/bash

addHostsToConfig() {
    DNS_IP_LIST=$1
    if [[ "$DNS_IP_LIST" == "" ]]; then
        echo "[!] Error! 'DNS:IP;' expected!"
        exit 1
    fi

    LAST_IP_ENTRY=""
    HOSTNAMES=""

    filename="/etc/gitlab-runner/config.toml"
    IFS=''
    NEW_TEXT=""
    NEWLINE=$'\n'
    while read line; do
        if [[ "$NEW_TEXT" != "" ]]; then
            NEW_TEXT="${NEW_TEXT}${NEWLINE}"
        fi
        NEW_TEXT="${NEW_TEXT}${line}"
        if [[ "$line" == *"[runners.kubernetes]"* ]]; then
            HOST_ALIAS_HEADER="    [[runners.kubernetes.host_aliases]]"
            NEW_TEXT="${NEW_TEXT}${NEWLINE}${HOST_ALIAS_HEADER}"
            IFS=";"
            for DNS_IP in $DNS_IP_LIST; do
                LAST_IP_ENTRY="$(echo -n $DNS_IP | cut -d ':' -f 1)"
                HOSTS="$(echo -n $DNS_IP | cut -d ':' -f 2)"
                STRING="\"ip\"=$IP"
                IFS=' '
                LAST_HOST="$(echo ${HOSTS##* })"
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
            IFS=''
        fi
    done < $filename
    NEW_TEXT="${NEW_TEXT}${NEWLINE}${line}"

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
fi

if [[ "$DNS_IP_LIST" != "" ]]; then
    addHostsToConfig "$DNS_IP_LIST"
fi

/usr/bin/dumb-init /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner
