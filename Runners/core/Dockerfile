# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

FROM mcr.microsoft.com/azure-cli:latest
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
    org.opencontainers.image.title="ADE Core" \
    org.opencontainers.image.description="The ADE Core runner is used as a base image for ADE deployments in Azure." \
    org.opencontainers.image.documentation="https://github.com/colbylwilliams/ade/tree/main/Runner/core" \
    org.opencontainers.image.licenses="MIT" \
    org.label-schema.schema-version="1.0" \
    org.label-schema.vendor="Microsoft" \
    org.label-schema.name="ADE Core Runner" \
    org.label-schema.version=$IMAGE_VERSION \
    org.label-schema.license="MIT" \
    org.label-schema.description="The ADE Core runner is used as a base image for ADE deployments in Azure." \
    org.label-schema.url="https://github.com/colbylwilliams/ade" \
    org.label-schema.usage="https://github.com/colbylwilliams/ade/tree/main/Runner/core" \
    org.label-schema.build-date=$BUILD_DATE \
    org.label-schema.vcs-url="https://github.com/colbylwilliams/ade.git" \
    org.label-schema.docker.cmd="docker run ghcr.io/colbylwilliams/ade/core:$IMAGE_VERSION"

COPY actions.d/* /actions.d/
COPY entrypoint.d/* /entrypoint.d/
COPY entrypoint.py /entrypoint.py

# Make entrypoint.py and all scripts in entrypoint.d and actions.d executable
RUN chmod +x /entrypoint.py \
    && mkdir -p /actions.d \
    && mkdir -p /entrypoint.d \
    && find /actions.d/ -type f -iname "*.sh" -exec chmod +x {} \; \
    && find /actions.d/ -type f -iname "*.py" -exec chmod +x {} \; \
    && find /entrypoint.d/ -type f -iname "*.sh" -exec chmod +x {} \; \
    && find /entrypoint.d/ -type f -iname "*.py" -exec chmod +x {} \;

# Terminate container on stop
STOPSIGNAL SIGTERM

CMD [ "" ]
ENTRYPOINT [ "/entrypoint.py" ]