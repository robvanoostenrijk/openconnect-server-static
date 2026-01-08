#!/usr/bin/env bash

IMAGE=$1

echo "[i] Clean dist folder"
rm -f -R ./dist
mkdir -p ./dist

for PLATFORM in linux/amd64 linux/arm64 linux/arm/v7
do
    CONTAINER=$(docker create --platform ${PLATFORM} "${IMAGE}:latest")
    echo "[i] Created container ${CONTAINER:0:12}"

    echo "[i] Extract assets"
    mkdir -p ./dist/bin ./dist/sbin
    docker cp "${CONTAINER}:/usr/local/bin/occtl" ./dist/bin
    docker cp "${CONTAINER}:/usr/local/bin/ocpasswd" ./dist/bin
    docker cp "${CONTAINER}:/usr/local/libexec/ocserv-fw" ./dist/libexec
    docker cp "${CONTAINER}:/usr/local/sbin/ocserv" ./dist/sbin
    docker cp "${CONTAINER}:/usr/local/sbin/ocserv-worker" ./dist/sbin

    echo "[i] Create distribution archive"
    XZ_OPT=-9 tar -C ./dist -Jcvf ./dist/openconnect-server-${PLATFORM//\//-}.tar.xz bin/occtl bin/ocpasswd bin/ocserv-fw sbin/ocserv sbin/ocserv-worker

    echo "[i] Removing container ${CONTAINER:0:12}"
    docker rm $CONTAINER
    rm -f -R ./dist/bin ./dist/sbin
done
