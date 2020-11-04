# k8s-cm-updater

## Overview
Used as an init container in a Kubernetes pod it can update a specified configmap
by substituting envars with their values that in turn can be loaded from a secret.

This helps to avoid embedding secrets into app configuraion and have a secret
delivery process separate.

## Configuration
|Environmetn variable name|Description|
|--|--|
|K8S_CM_UPDATER_NAME_IN|the configmap name to process (with envar names)|
|K8S_CM_UPDATER_NAME_OUT|the configmap name to save to (after replacing envars with values)|
|K8S_CM_UPDATER_DEBUG|if set to any value, the script will print the processed configmap to stdout|

## Example
See `example-k8s-cm-updater.yaml` for the full use case.
