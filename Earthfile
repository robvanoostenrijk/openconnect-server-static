VERSION 0.6

clean:
	LOCALLY
	RUN rm -f -R ./dist

build:
	FROM DOCKERFILE .
	SAVE ARTIFACT /usr/local/bin/occtl
	SAVE ARTIFACT /usr/local/bin/ocpasswd
	SAVE ARTIFACT /usr/local/bin/ocserv-fw
	SAVE ARTIFACT /usr/local/sbin/ocserv
	SAVE ARTIFACT /usr/local/sbin/ocserv-worker

package:
	ARG --required PLATFORM

	LOCALLY
	COPY +build/occtl dist/bin/
	COPY +build/ocpasswd dist/bin/
	COPY +build/ocserv-fw dist/bin/
	COPY +build/ocserv dist/sbin/
	COPY +build/ocserv-worker dist/sbin/
	RUN XZ_OPT=-9 tar -C dist -Jcvf dist/openconnect-server-${PLATFORM}.tar.xz bin/occtl bin/ocpasswd bin/ocserv-fw sbin/ocserv sbin/ocserv-worker \
	 && rm -f -R dist/bin dist/sbin

all:
	BUILD +clean
	BUILD --platform=linux/amd64 +package --PLATFORM=linux-amd64
	BUILD --platform=linux/arm64 +package --PLATFORM=linux-arm64
