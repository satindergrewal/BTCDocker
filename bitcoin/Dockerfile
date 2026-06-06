FROM ubuntu:latest AS builder

ARG TARGETARCH
ARG BITCOIN_VERSION=31.0

# Map Docker's TARGETARCH to Bitcoin Core's naming convention
# amd64 -> x86_64-linux-gnu
# arm64 -> aarch64-linux-gnu
# arm   -> arm-linux-gnueabihf
RUN case "${TARGETARCH}" in \
        amd64)  ARCH="x86_64-linux-gnu" ;; \
        arm64)  ARCH="aarch64-linux-gnu" ;; \
        arm)    ARCH="arm-linux-gnueabihf" ;; \
        *)      echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "ARCH=${ARCH}" > /tmp/arch.env

RUN apt-get update && apt-get install -y --no-install-recommends wget ca-certificates && \
    rm -rf /var/lib/apt/lists/*

# Download and verify Bitcoin Core
RUN . /tmp/arch.env && \
    FILENAME="bitcoin-${BITCOIN_VERSION}-${ARCH}.tar.gz" && \
    wget -q "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/${FILENAME}" && \
    wget -q "https://bitcoincore.org/bin/bitcoin-core-${BITCOIN_VERSION}/SHA256SUMS" && \
    grep "${FILENAME}" SHA256SUMS | sha256sum -c - && \
    tar -xzf "${FILENAME}" --strip-components=1 -C /usr/local && \
    rm -f "${FILENAME}" SHA256SUMS

# --- Final image ---
FROM ubuntu:latest

COPY --from=builder /usr/local/bin/bitcoind /usr/local/bin/bitcoind
COPY --from=builder /usr/local/bin/bitcoin-cli /usr/local/bin/bitcoin-cli

RUN userdel -r ubuntu 2>/dev/null; groupadd -r -g 1000 bitcoin && useradd -r -u 1000 -g bitcoin -m bitcoin
USER bitcoin

EXPOSE 8332 8333

ENTRYPOINT ["bitcoind"]
