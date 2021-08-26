#!/bin/sh
docker build -t ocserv-static .
docker run --detach --rm --name ocserv-static ocserv-static sleep 5

mkdir -p ./dist/bin ./dist/sbin

for FILE in "occtl" "ocpasswd" "ocserv-fw"
do
	docker cp "ocserv-static:/usr/local/bin/${FILE}" ./dist/bin
done

for FILE in "ocserv" "ocserv-worker"
do
	docker cp "ocserv-static:/usr/local/sbin/${FILE}" ./dist/sbin
done

docker stop ocserv-static
docker rmi ocserv-static

tar -C ./dist -zcvf ./dist/ocserv-static.tar.gz bin sbin
rm -f -R ./dist/bin ./dist/sbin