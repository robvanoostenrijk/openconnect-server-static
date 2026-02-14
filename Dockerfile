# syntax=docker/dockerfile:1.4
FROM alpine:latest AS builder

ENV	OCSERV_VERSION="1.4.0" \
	GNUTLS_VERSION="3.8.11" \
	LIBSECCOMP_VERSION="2.6.0" \
	LZ4_VERSION="1.10.0" \
	LLHTTP_VERSION="9.3.0"

#
# assets
#
COPY --link ["/assets", "/"]
COPY --link ["scratchfs", "/scratchfs"]

RUN	<<EOF

set -x
#sed -i -r 's/v\d+\.\d+/edge/g' /etc/apk/repositories
apk update
apk upgrade --no-interactive --latest
apk add --no-cache \
	build-base \
	cmake make \
	zlib-dev zlib-static \
	curl \
	geoip-dev \
	geoip-static \
	gmp-dev \
	gmp-static \
	gnupg \
	gperf \
	libev-dev \
	libidn2-dev \
	libidn2-static \
	libunistring-static \
	linux-headers \
	ncurses-dev \
	ncurses-static \
	nettle-dev \
	nettle-static \
	oath-toolkit-dev \
	openssl \
	readline-dev \
	readline-static \
	ronn \
	xz
mkdir -p /usr/src
cd /usr/src
set -- \
	1F42418905D8206AA754CCDC29EE58B996865171 \
	5D46CB0F763405A7053556F47A75A648B3F9220C \
	343C2FF0FBEE5EC2EDBEF399F3599FF828C67298
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys $@ || \
gpg --batch --keyserver hkps://peegeepee.com --recv-keys $@ \
gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes

#
# llhttp
#
curl --location --silent --output /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz "https://github.com/nodejs/llhttp/archive/refs/tags/release/v${LLHTTP_VERSION}.tar.gz"
mkdir -p /usr/src/llhttp
tar -xf /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz -C /usr/src/llhttp --strip-components=1
rm -f /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz.tar.gz
cd /usr/src/llhttp
cmake \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr
make
make install

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
	--disable-cxx \
	--disable-doc \
	--disable-gost \
	--disable-libdane \
	--disable-tests \
	--disable-tools \
	--disable-nls
make -j`nproc`
make install-strip

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
# Compile ocserv
#
cd /usr/src/ocserv
LIBREADLINE_LIBS="-lreadline -lncurses -lnettle" \
LIBNETTLE_LIBS="-lgmp" \
LIBGNUTLS_LIBS="-lgnutls -lgmp -lnettle -lhogweed -lidn2 -lunistring" \
LIBLZ4_CFLAGS="-I/usr/include" \
LIBLZ4_LIBS="-L/usr/include -llz4" \
CFLAGS="-Wno-type-limits" \
LIBS="-lz -lllhttp" \
LDFLAGS="-L/usr/local/lib -s -w -static" \
./configure \
	--with-local-talloc \
	--with-pager="" \
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

mkdir -p \
	/scratchfs/etc/ssl/certs \
	/scratchfs/etc/ssl/private \
	/scratchfs/usr/local/bin \
	/scratchfs/usr/local/libexec \
	/scratchfs/usr/local/sbin \
	/scratchfs/tmp \
	/scratchfs/var/run

cp /usr/local/bin/occtl /scratchfs/usr/local/bin
cp /usr/local/bin/ocpasswd /scratchfs/usr/local/bin
cp /usr/local/libexec/ocserv-fw /scratchfs/usr/local/libexec
cp /usr/local/sbin/ocserv /scratchfs/usr/local/sbin
cp /usr/local/sbin/ocserv-worker /scratchfs/usr/local/sbin
cp /etc/ssl/certs/ca-certificates.crt /scratchfs/etc/ssl/certs
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
