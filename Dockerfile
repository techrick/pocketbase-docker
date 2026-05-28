# Repackage the official upstream PocketBase release binary into a container
# image. VERSION is passed as a build-arg (without the leading "v").

# ---- fetch stage (runs NATIVELY on the runner arch; only downloads a file) ----
FROM --platform=$BUILDPLATFORM alpine:latest AS fetch
ARG VERSION=0.0.0
ARG TARGETARCH
ARG TARGETVARIANT
RUN apk add --no-cache wget ca-certificates unzip
RUN set -eux; \
    case "${TARGETARCH}${TARGETVARIANT}" in \
      amd64) PB_ARCH=amd64 ;; \
      arm64) PB_ARCH=arm64 ;; \
      armv7) PB_ARCH=armv7 ;; \
      *) echo "unsupported platform: ${TARGETARCH}${TARGETVARIANT}"; exit 1 ;; \
    esac; \
    wget -O /tmp/pb.zip \
      "https://github.com/pocketbase/pocketbase/releases/download/v${VERSION}/pocketbase_${VERSION}_linux_${PB_ARCH}.zip"; \
    unzip /tmp/pb.zip -d /pb/

# ---- runtime stage (target arch) ----
FROM alpine:latest
RUN apk add --no-cache ca-certificates tzdata
COPY --from=fetch /pb/pocketbase /pb/pocketbase
EXPOSE 8090
VOLUME /pb/pb_data
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
    CMD wget -qO- http://127.0.0.1:8090/api/health || exit 1
CMD ["/pb/pocketbase", "serve", "--http=0.0.0.0:8090", "--dir=/pb/pb_data"]