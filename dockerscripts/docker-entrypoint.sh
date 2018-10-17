#!/bin/sh
#
# Minio Cloud Storage, (C) 2017 Minio, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# If command starts with an option, prepend minio.
if [ "${1}" != "minio" ]; then
    if [ -n "${1}" ]; then
        set -- minio "$@"
    fi
fi

## Look for docker secrets in default documented location.
docker_secrets_env() {
    local ACCESS_KEY_FILE="/run/secrets/$MINIO_ACCESS_KEY_FILE"
    local SECRET_KEY_FILE="/run/secrets/$MINIO_SECRET_KEY_FILE"

    if [ -f $ACCESS_KEY_FILE -a -f $SECRET_KEY_FILE ]; then
        if [ -f $ACCESS_KEY_FILE ]; then
            export MINIO_ACCESS_KEY="$(cat "$ACCESS_KEY_FILE")"
        fi
        if [ -f $SECRET_KEY_FILE ]; then
            export MINIO_SECRET_KEY="$(cat "$SECRET_KEY_FILE")"
        fi
    fi
}

## Set access env from secrets if necessary.
docker_secrets_env

#exec /usr/bin/start.sh "$@"

shutdown () {
    echo Shutting down
    test -s /var/run/minio.pid && kill -TERM $(cat /var/run/minio.pid)
}
trap shutdown TERM INT

if [ -n "${MINIO_CLUSTER_ADDR}" ]; then
    MINIO_HOST=$(echo "${MINIO_CLUSTER_ADDR}" | sed -r "s/^(http:\/\/)//" | sed -r "s/\/.*//")
    MINIO_PATH=$(echo "${MINIO_CLUSTER_ADDR}" | sed -r "s/^(http:\/\/)//" | sed -r "s/${MINIO_HOST}//")
    if [ -z "${MINIO_HOST}" -o -z "${MINIO_PATH}" ]; then
        echo "Invalid value of follow environment variable MINIO_CLUSTER_ADDR"
        exit 1
    fi

    i=1
    while [ "$i" -le  10 ]; do
        host "${MINIO_HOST}" > /dev/null
        if [ $? -eq 0 ]; then
            export MINIO_ENDPOINTS=$(host "${MINIO_HOST}" | cut -f4 -d" " | sed -e "s/$/\\${MINIO_PATH}/" | sed -e "s/^/http:\/\//" | xargs)
            echo "Selected follow nodes: ${MINIO_ENDPOINTS}"

"$@" 2>&1 &
echo "$!" > /var/run/minio.pid
wait $!
rm /var/run/minio.pid

RC=$?
if [ "$RC" -eq 0 ]; then
    exit $RC
fi

        else
            echo "Sleep 50"
            sleep 50
        fi
        i=$(( i + 1 ))
    done
    if [ -z "${ADDRS}" ]; then
        echo "Could not find IPs"
        echo $(host "$MINIO_HOST")
        exit 1
    fi
fi

exit 0
