VERSION 0.6

clean:
	LOCALLY
	RUN rm -f -R ./dist

build:
	FROM DOCKERFILE .

package:
	FROM +build

	RUN set -x && \
	    mkdir -p /build/dist && \
            XZ_OPT=-9 tar -C /usr/local -Jcvf /build/dist/ocserv-static.tar.xz bin/occtl bin/ocpasswd bin/ocserv-fw sbin/ocserv sbin/ocserv-worker

	SAVE ARTIFACT /build/dist/ocserv-static.tar.xz AS LOCAL ./dist/ocserv-static.tar.xz

all:
	BUILD +clean
	BUILD +package
