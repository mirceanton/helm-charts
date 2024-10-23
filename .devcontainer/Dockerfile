## ================================================================================================
# Utility versions
## ================================================================================================
ARG MINIKUBE_VERSION=v1.34.0
ARG KUBECTL_VERSION=1.31.0
ARG HELM_VERSION=v3.15.4
ARG HELM_DOCS_VERSION=v1.14.2
ARG HELM_SCHEMA_VERSION=0.13.0

FROM docker.io/bitnami/kubectl:${KUBECTL_VERSION} AS kubectl
FROM jnorwood/helm-docs:${HELM_DOCS_VERSION} AS helm-docs


FROM alpine:3.19 AS minikube
ARG MINIKUBE_VERSION
RUN apk add --no-cache curl
RUN curl -Lo minikube https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-amd64 && \
    chmod +x minikube && \
    mv minikube /usr/local/bin/

FROM alpine:3.19 AS helm
ARG HELM_VERSION
RUN apk add --no-cache curl
RUN curl -Lo helm.tar.gz https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz && \
    tar xvf helm.tar.gz && \
    mv linux-amd64/helm /bin/helm


FROM alpine:3.19 AS helm-schema
ARG HELM_SCHEMA_VERSION
RUN apk add --no-cache curl
RUN curl -Lo helm-schema.tar.gz https://github.com/dadav/helm-schema/releases/download/${HELM_SCHEMA_VERSION}/helm-schema_${HELM_SCHEMA_VERSION}_Linux_x86_64.tar.gz && \
    tar xvf helm-schema.tar.gz && \
    mv helm-schema /bin/helm-schema

FROM mcr.microsoft.com/devcontainers/javascript-node:22-bookworm

COPY --from=minikube /usr/local/bin/minikube /usr/local/bin/minikube
COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=helm /bin/helm /usr/local/bin/helm
COPY --from=helm-docs /usr/local/bin/helm-docs /usr/local/bin/helm-docs
COPY --from=helm-schema /bin/helm-schema /usr/local/bin/helm-schema