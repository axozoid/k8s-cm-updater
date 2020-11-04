
.PHONY: build push all k d

tag ?= latest
pod_name ?= test-app
sample_manifest ?= example-k8s-cm-updater.yaml
repo ?= ozmate
image_name ?= k8s-cm-updater
wait_time = 20

build:
	docker build . -t $(image_name):$(tag)

push:
	docker tag $(image_name):$(tag) $(repo)/$(image_name):$(tag)
	docker push $(repo)/$(image_name):$(tag)

d: build push

k:
	@kubectl delete pod $(pod_name) || true
	@kubectl apply -f $(sample_manifest)
	@echo "> Wait $(wait_time)s for the pod to start.."
	@sleep $(wait_time)
	@echo "> Fetching logs:"
	@kubectl logs $(pod_name)

all: d k