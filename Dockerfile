# === Stage 1: Build Tor and dependencies ===
FROM debian:bullseye-slim AS builder-tor

ARG zlib_tag=v1.3.1
ARG zlib_url=https://github.com/madler/zlib.git
ARG openssl_tag=OpenSSL_1_1_1w
ARG openssl_url=https://github.com/openssl/openssl.git
ARG libevent_tag=release-2.1.12-stable
ARG libevent_url=https://github.com/libevent/libevent.git
ARG xz_tag=v5.8.1
ARG xz_url=https://git.tukaani.org/xz.git
ARG zstd_tag=v1.5.5
ARG zstd_url=https://github.com/facebook/zstd.git
ARG tor_tag=tor-0.4.8.17
ARG tor_url=https://gitlab.torproject.org/tpo/core/tor.git

# === Install build dependencies
RUN apt update && \
    apt install -y --no-install-recommends \
      git build-essential libtool autopoint po4a perl \
      pkg-config autoconf automake cmake curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

# === zlib
RUN git clone --depth=1 "$zlib_url" zlib && \
    cd "/build/zlib" && \
    git fetch --depth=1 origin tag $zlib_tag && \
    git checkout $zlib_tag && \
    sh ./configure --prefix="/build/zlib/dist" --static && \
    make -j"$(nproc)" && \
    make install

# === openssl
RUN git clone --depth=1 $openssl_url openssl && \
    cd "/build/openssl" && \
    git fetch --depth=1 origin tag $openssl_tag && \
    git checkout $openssl_tag && \
    sh ./config --prefix="/build/openssl/dist" --openssldir="/build/openssl/dist" no-shared no-dso no-zlib && \
    make depend && \
    make -j"$(nproc)" && \
    make install_sw

# === libevent
RUN git clone --depth=1 $libevent_url libevent && \
    cd "/build/libevent" && \
    git fetch --depth=1 origin tag $libevent_tag && \
    git checkout $libevent_tag && \
    sh -l ./autogen.sh && \
    PKG_CONFIG_PATH="/build/openssl/dist/lib/pkgconfig" \
      "/build/libevent/configure" --prefix="/build/libevent/dist" \
      --disable-shared --enable-static --with-pic \
      --disable-samples --disable-libevent-regress && \
    make -j"$(nproc)" && \
    make install

# === xz / liblzma
RUN git clone --depth=1 $xz_url xz && \
    cd "/build/xz" && \
    git fetch --depth=1 origin tag $xz_tag && \
    git checkout $xz_tag && \
    sh -l ./autogen.sh && \
    "/build/xz/configure" --prefix="/build/xz/dist" \
      --disable-shared --enable-static \
      --disable-doc --disable-scripts && \
    make -j"$(nproc)" && \
    make install

# === zstd
RUN git clone --depth=1 $zstd_url zstd && \
    cd "/build/zstd" && \
    git fetch --depth=1 origin tag $zstd_tag && \
    git checkout $zstd_tag && \
    mkdir -p "/build/zstd/cmake-build" && \
    cd "/build/zstd/cmake-build" && \
    cmake "/build/zstd/build/cmake" \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX="/build/zstd/dist" \
      -DZSTD_BUILD_SHARED=OFF \
      -DZSTD_BUILD_PROGRAMS=OFF \
      -DZSTD_BUILD_TESTS=OFF \
      -DZSTD_BUILD_CONTRIB=OFF && \
    make -j"$(nproc)" && \
    make install

# === tor
RUN git clone --depth=1 $tor_url tor && \
    cd "/build/tor" && \
    git fetch --depth=1 origin tag $tor_tag && \
    git checkout $tor_tag && \
    sh -l ./autogen.sh && \
    PKG_CONFIG_PATH="/build/openssl/dist/lib/pkgconfig:/build/zstd/dist/lib/pkgconfig:/build/xz/dist/lib/pkgconfig" \
      CFLAGS="-Os -s" \
      LDFLAGS="-s" \
      "/build/tor/configure" \
      --prefix="/build/tor/dist" \
      --sysconfdir=/etc --enable-static-tor \
      --enable-static-libevent --with-libevent-dir="/build/libevent/dist" \
      --enable-static-openssl --with-openssl-dir="/build/openssl/dist" \
      --enable-static-zlib --with-zlib-dir="/build/zlib/dist" \
      --enable-gpl --disable-seccomp --disable-libscrypt \
      --disable-tool-name-check --disable-gcc-hardening \
      --disable-html-manual --disable-manpage --disable-asciidoc \
      --disable-systemd --disable-unittests && \
    make -j"$(nproc)" && \
    make install

# === Stage 2: Build pluggable transport ===
FROM golang:alpine AS builder-lyrebird

ARG lyrebird_tag=lyrebird-0.6.1
ARG lyrebird_url=https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git

# === Install build dependencies
RUN apk add --no-cache git

WORKDIR /build

# === lyrebird
RUN git clone --depth=1 $lyrebird_url && \
    cd "/build/lyrebird" && \
    git fetch --depth=1 origin tag $lyrebird_tag && \
    git checkout "tags/$lyrebird_tag" -b "build-$lyrebird_tag" && \
    CGO_ENABLED=0 go build -ldflags="-X main.lyrebirdVersion=$lyrebird_tag -s -w" ./cmd/lyrebird


# === Stage 3: Minimal Tor and lyrebird runtime ===
FROM scratch
LABEL org.opencontainers.image.title="tor-zero" \
      org.opencontainers.image.description="A rootless, distroless, from-scratch Docker image for running Tor with optional Lyrebird transport." \
      org.opencontainers.image.url="https://ghcr.io/lanjelin/tor-zero" \
      org.opencontainers.image.source="https://github.com/Lanjelin/tor-zero" \
      org.opencontainers.image.documentation="https://github.com/Lanjelin/tor-zero" \
      org.opencontainers.image.version="0.4.8.17-0.6.1" \
      org.opencontainers.image.authors="Lanjelin" \
      org.opencontainers.image.licenses="BSD-3-Clause AND MIT"

USER 1000:1000
COPY --from=builder-tor /build/tor/dist/bin/tor /bin/tor
COPY --from=builder-tor /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/ca-certificates.crt
COPY --from=builder-lyrebird /build/lyrebird/lyrebird /bin/lyrebird

VOLUME ["/etc/tor"]
ENTRYPOINT ["/bin/tor"]

