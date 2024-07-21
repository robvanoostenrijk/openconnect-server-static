# syntax=docker/dockerfile:1.4
FROM alpine:latest AS builder

ENV	OCSERV_VERSION="1.3.0" \
	GNUTLS_VERSION="3.8.6" \
	LIBSECCOMP_VERSION="2.5.5"

#
# assets
#
COPY --link ["/assets", "/"]
COPY --link ["scratchfs", "/scratchfs"]

RUN	<<EOF

set -x
apk add --no-cache \
	brotli-dev \
	brotli-static \
	build-base \
	curl \
	gnupg \
	gperf \
	libev-dev \
	libidn2-dev \
	libidn2-static \
	libunistring-static \
	linux-headers \
	lz4-dev \
	lz4-static \
	ncurses-dev \
	ncurses-static \
	nettle-dev \
	nettle-static \
	oath-toolkit-dev \
	openssl \
	readline-dev \
	readline-static \
	unbound \
	xz \
	zlib-dev \
	zlib-static \
	zstd-dev \
	zstd-libs \
	zstd-static \
	--repository=http://dl-cdn.alpinelinux.org/alpine/latest-stable/main
mkdir -p /usr/src
cd /usr/src
set -- \
	1F42418905D8206AA754CCDC29EE58B996865171 \
	5D46CB0F763405A7053556F47A75A648B3F9220C
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys $@ || \
gpg --batch --keyserver hkps://peegeepee.com --recv-keys $@ \
gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes

#
# libseccomp
#
# Note: 'in_word_set()' in src/syscalls.perf.c conflicts with ocserv exports, rename it to '_in_word_set()'
curl --location --silent --output /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz "https://github.com/seccomp/libseccomp/releases/download/v${LIBSECCOMP_VERSION}/libseccomp-${LIBSECCOMP_VERSION}.tar.gz"
mkdir -p /usr/src/libseccomp
tar -xf /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz -C /usr/src/libseccomp --strip-components=1
rm -f /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz
cd /usr/src/libseccomp
./configure \
	--prefix=/usr \
	--disable-shared \
	--enable-static
sed -i 's/in_word_set/_in_word_set/g' src/syscalls.perf.c
make -j`nproc` install

#
# gnutls
#
curl --location --silent --output /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz "https://www.gnupg.org/ftp/gcrypt/gnutls/v${GNUTLS_VERSION%.*}/gnutls-${GNUTLS_VERSION}.tar.xz"
curl --location --silent --compressed --output /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz.sig "https://www.gnupg.org/ftp/gcrypt/gnutls/v${GNUTLS_VERSION%.*}/gnutls-${GNUTLS_VERSION}.tar.xz.sig"
gpg --verify /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz.sig
mkdir -p /usr/src/gnutls
tar -xf /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz -C /usr/src/gnutls --strip-components=1
rm -f /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz.sig
cd /usr/src/gnutls
unbound-anchor -a "/etc/unbound/root.key" ; true
CFLAGS="-Wno-analyzer-fd-leak -Wno-analyzer-null-dereference -Wno-analyzer-use-of-uninitialized-value -Wno-type-limits -Wno-unused-macros -Wno-stringop-overflow" \
./configure \
	--prefix=/usr \
	--enable-static=yes \
	--enable-shared=no \
	--with-included-libtasn1 \
	--with-included-unistring \
	--without-p11-kit \
	--without-tpm \
	--without-tpm2 \
	--disable-doc \
	--disable-tools \
	--disable-cxx \
	--disable-tests \
	--disable-nls \
	--disable-libdane \
	--disable-gost
make -j`nproc`
make install-strip

#
# Download ocserv
#
curl --location --silent --output /usr/src/ocserv-${OCSERV_VERSION}.tar.xz "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz"
curl --location --silent --compressed --output /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig"
gpg --verify /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig
mkdir -p /usr/src/ocserv
tar -xf /usr/src/ocserv-${OCSERV_VERSION}.tar.xz -C /usr/src/ocserv --strip-components=1
rm -f /usr/src/ocserv-${OCSERV_VERSION}.tar.xz /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig

#
# Compile ocserv
#
cd /usr/src/ocserv
LIBREADLINE_LIBS="-lreadline -lncurses -lnettle" \
LIBNETTLE_LIBS="-lgmp" \
LIBGNUTLS_LIBS="-lgnutls -lgmp -lnettle -lhogweed -lidn2 -lunistring" \
CFLAGS="-Wno-type-limits" \
LDFLAGS="-L/usr/local/lib -s -w -static" \
./configure \
	--with-local-talloc \
	--with-pager="" \
	--without-geoip \
	--without-gssapi \
	--without-libwrap \
	--without-maxmind \
	--without-pcl-lib \
	--without-protobuf \
	--without-radius \
	--without-tun-tests \
	--without-utmp
make -j`nproc`
make install-exec
file /usr/local/sbin/ocserv

cp /usr/local/bin/oc* /scratchfs/usr/local/bin
cp /usr/local/sbin/oc* /scratchfs/usr/local/sbin
cp /etc/ssl/certs/ca-certificates.crt /scratchfs/etc/ssl/certs
cp /etc/unbound/root.key /scratchfs/etc/unbound
echo "test" | /usr/local/bin/ocpasswd --passwd=/scratchfs/etc/ocserv/ocserv.passwd test

# Create self-signed certificate
openssl req -x509 -newkey rsa:4096 -nodes -keyout /scratchfs/etc/ssl/private/localhost.key -out /scratchfs/etc/ssl/localhost.pem -days 365 -sha256 -subj "/CN=localhost"

chmod 1777 /scratchfs/tmp

EOF

FROM scratch

COPY --from=builder /scratchfs /

EXPOSE 8443/tcp 8443/udp

ENTRYPOINT ["/usr/local/sbin/ocserv"]
CMD ["--foreground"]
