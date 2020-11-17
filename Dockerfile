FROM alpine:3.12.1

ENV KUBECTL_VERSION="v1.19.0"
ENV YQ_VERSION="3.4.1"

# install envstubst
RUN apk add --no-cache gettext curl bash jq
# install yq
RUN wget -O /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" \
    && chmod +x /usr/local/bin/yq
# install kubectl
RUN curl -Lo /usr/local/bin/kubectl https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
    && chmod +x /usr/local/bin/kubectl

COPY ./k8s-cm-updater.sh /usr/local/bin/k8s-cm-updater

ENTRYPOINT ["/usr/local/bin/k8s-cm-updater"]