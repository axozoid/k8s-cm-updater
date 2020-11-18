#!/usr/bin/env bash

TIMESTAMP=$(date +"%F %T %z")

# check if we need to be verbose
if [ -n "${K8S_CM_UPDATER_DEBUG}" ]; then
    echo "${TIMESTAMP} [DEBUG]: envars exposed to the container:"
    echo "------------------------------------------------------------------"
    env
    echo "------------------------------------------------------------------"
fi

show_help() {
    echo "[ERROR] Wrong number of parameters."
    echo ""
    echo "Usage: $0 K8S_CM_UPDATER_NAME_IN K8S_CM_UPDATER_NAME_OUT"
    echo "  K8S_CM_UPDATER_NAME_IN - the configmap name to process (with envars)"
    echo "  K8S_CM_UPDATER_NAME_OUT - the configmap name to save to (after replacing envars with values)"
    echo "  K8S_CM_UPDATER_WRITE_SECRET - if set to any value, a 'Secret' object will be created isntead of 'confiMmap'. The latter is default."
    echo ""
    echo "NOTE: if only K8S_CM_UPDATER_NAME_IN is provided, the original configmap will be overwritten."
    echo ""
    echo "TIP: Instead of passing the names as parameters, the envars with corresponding names can be used:"
    echo "K8S_CM_UPDATER_NAME_IN=app-config K8S_CM_UPDATER_NAME_OUT=app-config-out K8S_CM_UPDATER_WRITE_SECRET=true ./$0"
}

case "$#" in
    0)
        # if no arguments passed - we use envars
        K8S_CM_UPDATER_NAME_IN=${K8S_CM_UPDATER_NAME_IN}
        K8S_CM_UPDATER_NAME_OUT=${K8S_CM_UPDATER_NAME_OUT:-$K8S_CM_UPDATER_NAME_IN}
        ;;
    1)
        # if only 1 argument passed then we're going to
        # rewrite the existing configmap
        K8S_CM_UPDATER_NAME_IN=${1}
        K8S_CM_UPDATER_NAME_OUT=${1}
        ;;
    2) 
        # read both names from arguments
        K8S_CM_UPDATER_NAME_IN=${1}
        K8S_CM_UPDATER_NAME_OUT=${2}
        ;;
    3)
        # read both names and the type from arguments
        K8S_CM_UPDATER_NAME_IN=${1}
        K8S_CM_UPDATER_NAME_OUT=${2}
        K8S_CM_UPDATER_WRITE_SECRET=${3}
        ;;
    *) 
        show_help
        exit
        ;;
esac

[[ ${K8S_CM_UPDATER_NAME_IN} == ${K8S_CM_UPDATER_NAME_OUT} ]] && \
echo "${TIMESTAMP} [WARNING] existing configmap '${K8S_CM_UPDATER_NAME_IN}' will be overwritten."

# prepare tmp filenames
FILENAME_CM_IN=$(mktemp || exit 1)
FILENAME_CM_OUT=$(mktemp || exit 1)
FILENAME_CM_READY=$(mktemp || exit 1)
FILENAME_CM_READY_JSON=$(mktemp || exit 1)

# dump the configMap into a file
kubectl get configmap "${K8S_CM_UPDATER_NAME_IN}" -oyaml > "${FILENAME_CM_IN}" \
    || { echo "${TIMESTAMP} [ERROR] Cannot read configmap ${K8S_CM_UPDATER_NAME_IN}"; exit 1; }

if [ -n "${K8S_CM_UPDATER_DEBUG}" ]; then
    echo "------------------------------------------------------------------"
    echo "${TIMESTAMP} [DEBUG]: SOURCE ConfigMap:"
    echo "------------------------------------------------------------------"
    cat "${FILENAME_CM_IN}"
    echo "------------------------------------------------------------------"
fi

# removing all metadata fields and update the name
cat "${FILENAME_CM_IN}" \
    | yq d - 'metadata.uid' \
    | yq d - 'metadata.creationTimestamp' \
    | yq d - 'metadata.resourceVersion' \
    | yq d - 'metadata.selfLink' \
    | yq d - 'metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"' \
    | yq w -jP - 'metadata.name' "${K8S_CM_UPDATER_NAME_OUT}" \
    > "${FILENAME_CM_OUT}"

# update variables
envsubst "$(printf '${%s} ' $(env | sed 's/=.*//'))" < "${FILENAME_CM_OUT}" > "${FILENAME_CM_READY}"

# convert to a secret if needed
if [ -n "${K8S_CM_UPDATER_WRITE_SECRET}" ]; then
    cat "${FILENAME_CM_READY}" | jq 'with_entries(if .key == "data" then .value=(.value | to_entries | map( { (.key): (.value|@base64) } ) | add ) elif .key == "kind" then .value="Secret" else . end)' > "${FILENAME_CM_READY_JSON}"
    FILENAME_CM_READY=${FILENAME_CM_READY_JSON}
fi

# creating/updating the resource
kubectl apply -f "${FILENAME_CM_READY}" && echo "${TIMESTAMP} [SUCCESS] Resource '${K8S_CM_UPDATER_NAME_OUT}' has been written."

# if we're debugging - let's print out the new resource
if [ -n "${K8S_CM_UPDATER_DEBUG}" ]; then
    echo "${TIMESTAMP} [DEBUG]: DESTINATION Resource:"
    echo "------------------------------------------------------------------"
    cat "${FILENAME_CM_READY}"
    echo "------------------------------------------------------------------"
fi
