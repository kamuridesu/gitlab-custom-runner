#!/bin/bash

checkGitlabConnection() {
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
}

addHostsToConfig() {
    DNS_IP_LIST=$1
    if [[ "$DNS_IP_LIST" == "" ]]; then
        echo "[!] Error! 'IP:DNS;' expected!"
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

addAnnotationsToPod() {
    ANNOTATIONS=$1
    if [[ "$ANNOTATIONS" == "" ]]; then
        echo "[!] Error! 'key=value' expected!"
        exit 1
    fi
    oIFS="$IFS"

    filename="/etc/gitlab-runner/config.toml"
    NEW_TEXT="$(cat $filename)"
    NEWLINE=$'\n'
    ANNOTATION_HEADER="    [runners.kubernetes.pod_annotations]"
    NEW_TEXT="${NEW_TEXT}${NEWLINE}${ANNOTATION_HEADER}"
    IFS=' '
    for ANNOTATION in $ANNOTATIONS; do
        KEY="$(echo -n $ANNOTATION | cut -d '=' -f 1)"
        VALUE="$(echo -n $ANNOTATION | cut -d '=' -f 2)"
        TEXT="\"$KEY\" = \"$VALUE\""
        IFS=''
        NEW_TEXT="${NEW_TEXT}${NEWLINE}      ${TEXT}"
        IFS=' '
    done
    IFS=''
    echo $NEW_TEXT > /etc/gitlab-runner/config.toml
    IFS="$oIFS"
}

main() {
    echo "[*] Starting"
    checkGitlabConnection
    gitlab-runner register --non-interactive --url="${GITLAB_HOST}" --registration-token="${REGISTRATION_TOKEN}" --executor="${EXECUTOR}" --description="${DESCRIPTION}" --tag-list="${TAG}"

    if [ "${EXECUTOR}" == "kubernetes" ]; then
        echo "[*] Adding namespace to config"
        sed -i "s/namespace = \"\"/namespace = \"${NAMESPACE}\"/" /etc/gitlab-runner/config.toml
        if [[ "$DNS_IP_LIST" != "" ]]; then 
            echo "[*] Adding host aliases"
            addHostsToConfig "$DNS_IP_LIST"
        fi
        if [[ "$POD_ANNOTATIONS" ]]; then
            echo "[*] Adding pod annotations"
            addAnnotationsToPod "$POD_ANNOTATIONS"
        fi
    fi
    echo "[*] Done!"

    /usr/bin/dumb-init /entrypoint run --user=gitlab-runner --working-directory=/home/gitlab-runner
}

main