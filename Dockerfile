FROM alpine:latest

ENV	OCSERV_VERSION="1.1.3" \
	NETTLE_VERSION="3.7.3" \
	GNUTLS_VERSION="3.7.2" \
	LIBEV_VERSION="4.33" \
	LZ4_VERSION="1.9.3"

RUN	set -x && \
	apk add --no-cache \
	build-base \
	curl \
	gnupg \
	linux-headers \
	m4 && \
	mkdir -p /build && \
	cd /build && \
	set -- \
		343C2FF0FBEE5EC2EDBEF399F3599FF828C67298 \
		462225C3B46F34879FC8496CD605848ED7E69871 \
		1F42418905D8206AA754CCDC29EE58B996865171 && \
	gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys $@ || \
	gpg --batch --keyserver hkps://peegeepee.com --recv-keys $@ && \
	gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes
#
# assets
#
COPY ["/assets", "/"]
#
# nettle
#
RUN set -x && \
	curl --location --silent --output /build/nettle-${NETTLE_VERSION}.tar.gz "https://ftp.gnu.org/gnu/nettle/nettle-${NETTLE_VERSION}.tar.gz" && \
	curl --location --silent --compressed --output /build/nettle-${NETTLE_VERSION}.tar.gz.sig "https://ftp.gnu.org/gnu/nettle/nettle-${NETTLE_VERSION}.tar.gz.sig" && \
	gpg --verify /build/nettle-${NETTLE_VERSION}.tar.gz.sig && \
	tar -xf /build/nettle-${NETTLE_VERSION}.tar.gz -C /build && \
	rm -f /build/nettle-${NETTLE_VERSION}.tar.gz /build/nettle-${NETTLE_VERSION}.tar.gz.sig && \
	cd /build/nettle-${NETTLE_VERSION} && \
	CFLAGS="-I/usr/local/include" \
	LDFLAGS="-L/usr/local/lib" \
	./configure \
		--enable-mini-gmp \
		--enable-x86-aesni \
		--enable-x86-sha-ni \
		--enable-static \
		--disable-shared \
		--disable-documentation && \
	sed 's|cnd-copy\.c |&cnd-memcpy.c |' Makefile -i && \
	make -j`nproc` install
#
# gnutls
#
RUN set -x && \
	curl --location --silent --output /build/gnutls-${GNUTLS_VERSION}.tar.xz "https://www.gnupg.org/ftp/gcrypt/gnutls/v$(echo ${GNUTLS_VERSION} | cut -c1-3)/gnutls-${GNUTLS_VERSION}.tar.xz" && \
	curl --location --silent --compressed --output /build/gnutls-${GNUTLS_VERSION}.tar.xz.sig "https://www.gnupg.org/ftp/gcrypt/gnutls/v$(echo ${GNUTLS_VERSION} | cut -c1-3)/gnutls-${GNUTLS_VERSION}.tar.xz.sig" && \
	gpg --verify /build/gnutls-${GNUTLS_VERSION}.tar.xz.sig && \
	tar -xf /build/gnutls-${GNUTLS_VERSION}.tar.xz -C /build && \
	rm -f /build/gnutls-${GNUTLS_VERSION}.tar.xz /build/gnutls-${GNUTLS_VERSION}.tar.xz.sig && \
	cd /build/gnutls-${GNUTLS_VERSION} && \
	NETTLE_CFLAGS="-I/usr/local/include" \
	NETTLE_LIBS="-L/usr/local/lib -lhogweed" \
	HOGWEED_CFLAGS="-I/usr/local/include" \
	HOGWEED_LIBS="-L/usr/local/lib" \
	./configure \
		--with-nettle-mini \
		--enable-static=yes \
		--enable-shared=no \
		--with-included-libtasn1 \
		--with-included-unistring \
		--without-p11-kit \
		--without-tpm \
		--disable-doc \
		--disable-tools \
		--disable-cxx \
		--disable-tests \
		--disable-nls \
		--disable-guile \
		--disable-libdane \
		--disable-gost && \
	make -j`nproc` && \
	make install
#
# libev
#
RUN set -x && \
	curl --location --silent --output /build/libev-${LIBEV_VERSION}.tar.gz "http://dist.schmorp.de/libev/libev-${LIBEV_VERSION}.tar.gz" && \
	curl --location --silent --compressed --output /build/libev-${LIBEV_VERSION}.tar.gz.sig "http://dist.schmorp.de/libev/libev-${LIBEV_VERSION}.tar.gz.sig" && \
	#gpg --verify /build/libev-${LIBEV_VERSION}.tar.gz.sig && \
	tar -xf /build/libev-${LIBEV_VERSION}.tar.gz -C /build && \
	rm -f /build/libev-${LIBEV_VERSION}.tar.gz /build/libev-${LIBEV_VERSION}.tar.gz.sig && \
	cd /build/libev-${LIBEV_VERSION} && \
	./configure \
		--enable-static \
		--disable-shared && \
	make -j`nproc` && \
	make install
#
# lz4
#
RUN set -x && \
	curl --location --silent --output /build/lz4-${LZ4_VERSION}.tar.gz "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz" && \
	tar -xf /build/lz4-${LZ4_VERSION}.tar.gz -C /build && \
	rm -f /build/lz4-${LZ4_VERSION}.tar.gz && \
	cd /build/lz4-${LZ4_VERSION} && \
	make -j`nproc` liblz4.a && \
	install lib/liblz4.a /usr/local/lib && \
	install lib/lz4*.h /usr/local/include
#
#	Download ocserv
#
RUN set -x && \
	curl --location --silent --output /build/ocserv-${OCSERV_VERSION}.tar.xz "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz" && \
	curl --location --silent --compressed --output /build/ocserv-${OCSERV_VERSION}.tar.xz.sig "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig" && \
	gpg --verify /build/ocserv-${OCSERV_VERSION}.tar.xz.sig && \
	tar -xf /build/ocserv-${OCSERV_VERSION}.tar.xz -C /build && \
	rm -f /build/ocserv-${OCSERV_VERSION}.tar.xz /build/ocserv-${OCSERV_VERSION}.tar.xz.sig

RUN set -x && \
#
# readline stub
#
	cd /build/readline && \
	cc -xc -c -O2 readline_stub.c && \
	ar rcs /usr/local/lib/libreadline.a readline_stub.o && \
#
#	Compile ocserv
#
	cd /build/ocserv-${OCSERV_VERSION} && \
	LIBNETTLE_CFLAGS="-I/usr/local/include" \
	LIBNETTLE_LIBS="-L/usr/local/lib -lnettle" \
	LIBGNUTLS_CFLAGS="-I/usr/local/include" \
	LIBGNUTLS_LIBS="-L/usr/local/lib -lgnutls -lhogweed -lnettle" \
	LIBLZ4_CFLAGS="-I/usr/include" \
	LIBLZ4_LIBS="-L/usr/include -llz4" \
	LIBREADLINE_CFLAGS="-I/usr/include" \
	LIBREADLINE_LIBS="-L/usr/local/lib -lreadline" \
	LDFLAGS="-L/usr/local/lib -s -w -static" \
	./configure \
		--disable-seccomp \
		--with-local-talloc \
		--with-pager="" \
		--without-geoip \
		--without-gssapi \
		--without-http-parser \
		--without-liboath \
		--without-libwrap \
		--without-maxmind \
		--without-nuttcp-tests \
		--without-pam \
		--without-pcl-lib \
		--without-protobuf \
		--without-radius \
		--without-tun-tests \
		--without-utmp && \
	make -j`nproc` && \
	make install
