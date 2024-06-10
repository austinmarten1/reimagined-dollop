# Stage 1: Build OpenBAO and UI
FROM docker.io/library/golang:1.22-bullseye AS builder

ARG REPO_URL=https://github.com/openbao/openbao.git
ARG BIN_NAME
ARG PRODUCT_VERSION
ARG PRODUCT_REVISION

ENV GOPATH=/go
ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH

RUN apt-get update && apt-get install -y make git curl gnupg && \
    curl -sL https://deb.nodesource.com/setup_16.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn

RUN mkdir -p /src/openbao
WORKDIR /src/openbao

RUN git clone ${REPO_URL} .

RUN if [ -d "ui" ]; then cd ui && yarn install; else echo "ui directory not found"; fi

RUN make ember-dist
RUN make bin BUILD_TAGS=ui

FROM registry.access.redhat.com/ubi9-minimal:9.4 as runtime

ARG BIN_NAME
ARG PRODUCT_VERSION
ARG PRODUCT_REVISION

LABEL name="OpenBao" \
      maintainer="OpenBao <openbao@lists.lfedge.org>" \
      vendor="OpenBao" \
      version=${PRODUCT_VERSION} \
      release=${PRODUCT_REVISION} \
      revision=${PRODUCT_REVISION} \
      summary="OpenBao is a tool for securely accessing secrets." \
      description="OpenBao is a tool for securely accessing secrets. A secret is anything that you want to tightly control access to, such as API keys, passwords, certificates, and more. OpenBao provides a unified interface to any secret, while providing tight access control and recording a detailed audit log."

COPY --from=builder /src/openbao/LICENSE /licenses/openbao.txt

ENV NAME=$NAME
ENV VERSION=$VERSION

RUN set -eux; \
    microdnf install -y ca-certificates gnupg openssl tzdata procps shadow-utils util-linux && \
    microdnf clean all

RUN groupadd --gid 1000 openbao && \
    adduser --uid 100 --system -g openbao openbao && \
    usermod -a -G root openbao

ENV HOME /home/openbao
RUN mkdir -p /openbao/logs /openbao/file /openbao/config /openbao/ui $HOME && \
    chown -R openbao:openbao /openbao $HOME && \
    chmod -R 755 /openbao $HOME

COPY --from=builder /src/openbao/$BIN_NAME /bin/bao
COPY --from=builder /src/openbao/ui /openbao/ui

VOLUME /openbao/logs
VOLUME /openbao/file
EXPOSE 8200



COPY --from=builder /src/openbao/.release/docker/ubi-docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
COPY ./config.hcl /openbao/config/config.hcl

USER openbao

ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]

