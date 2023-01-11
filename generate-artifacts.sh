#!/bin/sh
docker build -t ocserv-static .
CONTAINER=$(docker create ocserv-static)

mkdir -p ./dist/bin ./dist/sbin

for FILE in "occtl" "ocpasswd" "ocserv-fw"
do
	docker cp "${CONTAINER}:/usr/local/bin/${FILE}" ./dist/bin
done

for FILE in "ocserv" "ocserv-worker"
do
	docker cp "${CONTAINER}:/usr/local/sbin/${FILE}" ./dist/sbin
done

docker rm "${CONTAINER}"
docker rmi ocserv-static

XZ_OPT=-9 tar -C ./dist -Jcvf ./dist/ocserv-static.tar.xz bin sbin
rm -f -R ./dist/bin ./dist/sbin
