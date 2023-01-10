VERSION 0.6

clean:
	LOCALLY
	RUN rm -f -R ./dist

build:
	FROM DOCKERFILE .

package:
	ARG --required PLATFORM
	FROM +build

	RUN set -x \
&&		mkdir -p /tmp/dist \
&&		tar -C /usr/local -zcvf /tmp/dist/openconnect-server.tar.gz bin/occtl bin/ocpasswd bin/ocserv-fw sbin/ocserv sbin/ocserv-worker

	SAVE ARTIFACT /tmp/dist/openconnect-server.tar.gz AS LOCAL ./dist/openconnect-server-${PLATFORM}.tar.gz

all:
	BUILD +clean
	BUILD --platform=linux/amd64 +package --PLATFORM=amd64
	BUILD --platform=linux/arm64 +package --PLATFORM=arm64
