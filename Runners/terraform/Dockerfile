# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

ARG IMAGE_VERSION=latest

FROM ghcr.io/colbylwilliams/ade/core:${IMAGE_VERSION}
WORKDIR /

ARG IMAGE_VERSION

# Metadata as defined at http://label-schema.org
ARG BUILD_DATE

LABEL maintainer="Microsoft" \
    org.opencontainers.image.created=$BUILD_DATE \
    org.opencontainers.image.url="https://github.com/colbylwilliams/ade" \
    org.opencontainers.image.source="https://github.com/colbylwilliams/ade" \
    org.opencontainers.image.version=$IMAGE_VERSION \
    org.opencontainers.image.vendor="Microsoft" \
    org.opencontainers.image.title="ADE Terraform Runner" \
    org.opencontainers.image.description="The ADE Terraform runner is used as a base image for ADE deployments in Azure." \
    org.opencontainers.image.documentation="https://github.com/colbylwilliams/ade/tree/main/Runner/terraform" \
    org.opencontainers.image.licenses="MIT" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.vendor="Microsoft" \
    org.label-schema.name="ADE Terraform Runner" \
    org.label-schema.version=$IMAGE_VERSION \
    org.label-schema.license="MIT" \
    org.label-schema.description="The ADE Terrafomr runner is used as a base image for ADE deployments in Azure." \
    org.label-schema.url="https://github.com/colbylwilliams/ade" \
    org.label-schema.usage="https://github.com/colbylwilliams/ade/tree/main/Runner/terraform" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.vcs-url="https://github.com/colbylwilliams/ade.git" \
    org.label-schema.docker.cmd="docker run ghcr.io/colbylwilliams/ade/terraform:$IMAGE_VERSION"


# install terraform
RUN apk add --no-cache terraform --repository=http://dl-cdn.alpinelinux.org/alpine/edge/community

# Grab all .sh files from actions.d, copy to
# root actions.d, and ake them all executable
COPY actions.d/* /actions.d/
RUN find /actions.d/ -type f -iname "*.sh" -exec chmod +x {} \; \
    && find /actions.d/ -type f -iname "*.py" -exec chmod +x {} \;
