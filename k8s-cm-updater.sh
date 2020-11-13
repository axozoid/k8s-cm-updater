#!/usr/bin/env bash

TIMESTAMP=$(date +"%F %T %z")
SLEEP_TIME=60

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
    echo ""
    echo "NOTE: if only K8S_CM_UPDATER_NAME_IN is provided, the original configmap will be overwritten."
    echo ""
    echo "TIP: Instead of passing the names as parameters, the envars with corresponding names can be used:"
    echo "K8S_CM_UPDATER_NAME_IN=app-config K8S_CM_UPDATER_NAME_OUT=app-config-out ./k8s-cm-updater.sh"
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

# download the configMap into the file while
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
    | yq w - 'metadata.annotations."argocd.argoproj.io/compare-options"' 'IgnoreExtraneous' \
    | yq d - 'metadata.labels."app.kubernetes.io/instance"' \
    | yq d - 'metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"' \
    | yq w - 'metadata.name' "${K8S_CM_UPDATER_NAME_OUT}" \
    > "${FILENAME_CM_OUT}"

# update variables
envsubst <"${FILENAME_CM_OUT}" > "${FILENAME_CM_IN}"

# if we're debugging - let's print out the new configmap
if [ -n "${K8S_CM_UPDATER_DEBUG}" ]; then
    echo "${TIMESTAMP} [DEBUG]: DESTINATION ConfigMap:"
    echo "------------------------------------------------------------------"
    cat "${FILENAME_CM_IN}"
    echo "------------------------------------------------------------------"
    sleep ${SLEEP_TIME}
fi

# creating/updating the configmap
kubectl apply -f "${FILENAME_CM_IN}" && echo "${TIMESTAMP} [SUCCESS] Configmap '${K8S_CM_UPDATER_NAME_OUT}' has been written."