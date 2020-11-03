#!/usr/bin/env bash

# check parameters
[[ (("$#" -eq 0) || ("$#" -gt 2)) ]] && { echo "ERROR: Illegal number of parameters"; exit 1; }

# configMap name to work with
K8S_CONFIGMAP_NAME_IN="${1}"

# prepare tmp filenames
FILENAME_CM_IN=$(mktemp || exit 1)
FILENAME_CM_OUT=$(mktemp || exit 1)

# if there was just one argument passed into the script
# we need to rewrite the existing configMap
if [[ "$#" -eq 1 ]]; then
    K8S_CONFIGMAP_NAME_OUT="${1}"
    echo "WARNING: the script is set to overwrite the existing configMap ${K8S_CONFIGMAP_NAME_IN}."
else
    K8S_CONFIGMAP_NAME_OUT="${2}"
fi

# download the configMap into the file while
kubectl get configmap "${K8S_CONFIGMAP_NAME_IN}" -oyaml > "${FILENAME_CM_IN}" \
    || { echo "ERROR: Cannot read secret ${K8S_CONFIGMAP_NAME_IN}"; exit 1; }

# removing all metadata fields and update the name
cat "${FILENAME_CM_IN}" \
    | yq d - 'metadata.uid' \
    | yq d - 'metadata.creationTimestamp' \
    | yq d - 'metadata.resourceVersion' \
    | yq d - 'metadata.annotations."kubectl.kubernetes.io/last-applied-configuration"' \
    | yq w - 'metadata.name' "${K8S_CONFIGMAP_NAME_OUT}"
    > "${FILENAME_CM_IN}"

# update variables
envsubst < ${FILENAME_CM_IN} > ${FILENAME_CM_OUT}

cat "${FILENAME_CM_OUT}"

# kubectl apply -f "${FILENAME_CM_OUT}"