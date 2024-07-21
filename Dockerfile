# syntax=docker/dockerfile:1.4
FROM alpine:latest AS builder

ENV	OCSERV_VERSION="1.3.0" \
	NETTLE_VERSION="3.10" \
	GNUTLS_VERSION="3.8.6" \
	LIBSECCOMP_VERSION="2.5.5" \
	LIBEV_VERSION="4.33" \
	LZ4_VERSION="1.9.4"

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
	libidn2-dev \
	libidn2-static \
	libunistring-static \
	linux-headers \
	m4 \
	oath-toolkit-dev \
	openssl \
	signify \
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
	343C2FF0FBEE5EC2EDBEF399F3599FF828C67298 \
	462225C3B46F34879FC8496CD605848ED7E69871 \
	1F42418905D8206AA754CCDC29EE58B996865171 \
	5D46CB0F763405A7053556F47A75A648B3F9220C \
	A6AB53A01D237A94F9EEC4D0412748A40AFCC2FB
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys $@ || \
gpg --batch --keyserver hkps://peegeepee.com --recv-keys $@ \
gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes

#
# nettle
#
curl --location --silent --output /usr/src/nettle-${NETTLE_VERSION}.tar.gz "https://ftp.gnu.org/gnu/nettle/nettle-${NETTLE_VERSION}.tar.gz"
curl --location --silent --compressed --output /usr/src/nettle-${NETTLE_VERSION}.tar.gz.sig "https://ftp.gnu.org/gnu/nettle/nettle-${NETTLE_VERSION}.tar.gz.sig"
gpg --verify /usr/src/nettle-${NETTLE_VERSION}.tar.gz.sig
mkdir -p /usr/src/nettle
tar -xf /usr/src/nettle-${NETTLE_VERSION}.tar.gz -C /usr/src/nettle --strip-components=1
rm -f /usr/src/nettle-${NETTLE_VERSION}.tar.gz /usr/src-${NETTLE_VERSION}.tar.gz.sig
cd /usr/src/nettle
CFLAGS="-I/usr/local/include" \
LDFLAGS="-L/usr/local/lib" \
./configure \
	--enable-arm64-crypto \
	--enable-mini-gmp \
	--enable-x86-aesni \
	--enable-x86-pclmul \
	--enable-x86-sha-ni \
	--enable-static \
	--disable-shared \
	--disable-documentation
sed 's|cnd-copy\.c |&cnd-memcpy.c |' Makefile -i
make -j`nproc` install-headers install-static

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
	--disable-shared \
	--enable-static
sed -i 's/in_word_set/_in_word_set/g' src/syscalls.perf.c
make install

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
NETTLE_CFLAGS="-I/usr/local/include" \
NETTLE_LIBS="-L/usr/local/lib -lhogweed" \
HOGWEED_CFLAGS="-I/usr/local/include" \
HOGWEED_LIBS="-L/usr/local/lib" \
	./configure \
		--with-libseccomp-prefix=/usr/local \
		--with-nettle-mini \
		--enable-static=yes \
		--enable-shared=no \
		--with-included-libtasn1 \
		--with-included-unistring \
		--without-brotli \
		--without-p11-kit \
		--without-tpm \
		--without-tpm2 \
		--without-zstd \
		--disable-doc \
		--disable-tools \
		--disable-cxx \
		--disable-tests \
		--disable-nls \
		--disable-guile \
		--disable-libdane \
		--disable-gost
make -j`nproc`
make install-strip

#
# libev
#
curl --location --silent --output /usr/src/libev-${LIBEV_VERSION}.tar.gz "http://dist.schmorp.de/libev/libev-${LIBEV_VERSION}.tar.gz"
curl --location --silent --compressed --output /usr/src/libev-${LIBEV_VERSION}.tar.gz.sig "http://dist.schmorp.de/libev/libev-${LIBEV_VERSION}.tar.gz.sig"
curl --location --silent --compressed --output /usr/src/signing-key.pub "http://dist.schmorp.de/signing-key.pub"
signify -V -p /usr/src/signing-key.pub -m /usr/src/libev-${LIBEV_VERSION}.tar.gz
mkdir -p /usr/src/libev
tar -xf /usr/src/libev-${LIBEV_VERSION}.tar.gz -C /usr/src/libev --strip-components=1
rm -f /usr/src/libev-${LIBEV_VERSION}.tar.gz /usr/src/libev-${LIBEV_VERSION}.tar.gz.sig /usr/src/signing-key.pub
cd /usr/src/libev
./configure \
	--enable-static \
	--disable-shared
make -j`nproc`
make install-includeHEADERS install-libLTLIBRARIES

#
# lz4
#
curl --location --silent --output /usr/src/lz4-${LZ4_VERSION}.tar.gz "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz"
mkdir -p /usr/src/lz4
tar -xf /usr/src/lz4-${LZ4_VERSION}.tar.gz -C /usr/src/lz4 --strip-components=1
rm -f /usr/src/lz4-${LZ4_VERSION}.tar.gz
cd /usr/src/lz4
make -j`nproc` liblz4.a
install lib/liblz4.a /usr/local/lib
install lib/lz4*.h /usr/local/include

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
# readline stub
#
cd /usr/src/readline
cc -xc -c -O2 readline_stub.c
ar rcs /usr/local/lib/libreadline.a readline_stub.o

#
# Compile ocserv
#
cd /usr/src/ocserv
LIBNETTLE_CFLAGS="-I/usr/local/include" \
LIBNETTLE_LIBS="-L/usr/local/lib -lnettle" \
LIBGNUTLS_CFLAGS="-I/usr/local/include" \
LIBGNUTLS_LIBS="-L/usr/local/lib -lgnutls -lhogweed -lnettle -lzstd -lz -lbrotlidec -lbrotlienc -lbrotlicommon -lunistring -lidn2" \
LIBLZ4_CFLAGS="-I/usr/include" \
LIBLZ4_LIBS="-L/usr/include -llz4" \
LIBREADLINE_CFLAGS="-I/usr/include" \
LIBREADLINE_LIBS="-L/usr/local/lib -lreadline" \
LDFLAGS="-L/usr/local/lib -s -w -static" \
./configure \
	--with-local-talloc \
	--with-pager="" \
	--without-geoip \
	--without-gssapi \
	--without-http-parser \
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
