# syntax=docker/dockerfile:1.4
FROM alpine:latest AS builder

ENV	OCSERV_VERSION="1.6.0" \
	GNUTLS_VERSION="3.8.13" \
	LIBSECCOMP_VERSION="2.6.1" \
	LIBSECCOMP_SHA256="501f66c667225d53791b97e1d7cf85ab764c297d04881f60f38f451c4b0ee1be" \
	LZ4_VERSION="1.10.0" \
	LZ4_SHA256="537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b" \
	LLHTTP_VERSION="9.4.3" \
	LLHTTP_SHA256="1eb813c7437b31a87496a1cd3ed79f00746720f5e7e29c79b42c02cb69f36c39"

RUN	<<EOF

set -euo pipefail
set -x
#sed -i -r 's/v\d+\.\d+/edge/g' /etc/apk/repositories
apk update
apk upgrade --no-interactive --latest
apk add --no-cache \
	build-base \
	cmake \
	zlib-dev zlib-static \
	curl \
	file \
	gmp-dev \
	gmp-static \
	gnupg \
	gperf \
	libev-dev \
	libidn2-dev \
	libidn2-static \
	libunistring-static \
	linux-headers \
	meson \
	ncurses-dev \
	ncurses-static \
	nettle-dev \
	nettle-static \
	oath-toolkit-dev \
	openssl \
	protobuf-c-compiler \
	readline-dev \
	readline-static \
	xz
mkdir -p /usr/src
cd /usr/src
set -- \
	1F42418905D8206AA754CCDC29EE58B996865171 \
	5D46CB0F763405A7053556F47A75A648B3F9220C \
	A6AB53A01D237A94F9EEC4D0412748A40AFCC2FB \
	343C2FF0FBEE5EC2EDBEF399F3599FF828C67298
gpg --batch --keyserver hkps://keyserver.ubuntu.com --recv-keys "$@" || \
	gpg --batch --keyserver hkps://peegeepee.com --recv-keys "$@"
gpg --yes --list-keys --fingerprint --with-colons | sed -E -n -e 's/^fpr:::::::::([0-9A-F]+):$/\1:6:/p' | gpg --import-ownertrust --yes

#
# llhttp
#
curl -fsSL --output /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz "https://github.com/nodejs/llhttp/archive/refs/tags/release/v${LLHTTP_VERSION}.tar.gz"
echo "${LLHTTP_SHA256}  /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz" | sha256sum -c -
mkdir -p /usr/src/llhttp
tar -xf /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz -C /usr/src/llhttp --strip-components=1
rm -f /usr/src/llhttp-${LLHTTP_VERSION}.tar.gz
cd /usr/src/llhttp
cmake -S . -B build \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_SHARED_LIBS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr
cmake --build build -j"$(nproc)"
cmake --install build

#
# libseccomp
#
# Note: 'in_word_set()' in src/syscalls.perf.c conflicts with ocserv exports, rename it to '_in_word_set()'
curl -fsSL --output /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz "https://github.com/seccomp/libseccomp/releases/download/v${LIBSECCOMP_VERSION}/libseccomp-${LIBSECCOMP_VERSION}.tar.gz"
echo "${LIBSECCOMP_SHA256}  /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz" | sha256sum -c -
mkdir -p /usr/src/libseccomp
tar -xf /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz -C /usr/src/libseccomp --strip-components=1
rm -f /usr/src/libseccomp-${LIBSECCOMP_VERSION}.tar.gz
cd /usr/src/libseccomp
./configure \
	--prefix=/usr \
	--disable-shared \
	--enable-static
sed -i 's/in_word_set/_in_word_set/g' src/syscalls.perf.c
make -j"$(nproc)" install

#
# gnutls
#
curl -fsSL --output /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz "https://www.gnupg.org/ftp/gcrypt/gnutls/v${GNUTLS_VERSION%.*}/gnutls-${GNUTLS_VERSION}.tar.xz"
curl -fsSL --compressed --output /usr/src/gnutls-${GNUTLS_VERSION}.tar.xz.sig "https://www.gnupg.org/ftp/gcrypt/gnutls/v${GNUTLS_VERSION%.*}/gnutls-${GNUTLS_VERSION}.tar.xz.sig"
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
make -j"$(nproc)"
make install-strip

#
# lz4
#
curl -fsSL --output /usr/src/lz4-${LZ4_VERSION}.tar.gz "https://github.com/lz4/lz4/archive/refs/tags/v${LZ4_VERSION}.tar.gz"
echo "${LZ4_SHA256}  /usr/src/lz4-${LZ4_VERSION}.tar.gz" | sha256sum -c -
mkdir -p /usr/src/lz4
tar -xf /usr/src/lz4-${LZ4_VERSION}.tar.gz -C /usr/src/lz4 --strip-components=1
rm -f /usr/src/lz4-${LZ4_VERSION}.tar.gz
cd /usr/src/lz4
make -j"$(nproc)" -C lib liblz4.a liblz4.pc PREFIX=/usr
install -m 644 lib/liblz4.a /usr/lib/
install -m 644 lib/lz4*.h /usr/include/
install -d /usr/lib/pkgconfig
install -m 644 lib/liblz4.pc /usr/lib/pkgconfig/

#
# Download ocserv
#
curl -fsSL --output /usr/src/ocserv-${OCSERV_VERSION}.tar.xz "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz"
curl -fsSL --compressed --output /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig "https://www.infradead.org/ocserv/download/ocserv-${OCSERV_VERSION}.tar.xz.sig"
gpg --verify /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig
mkdir -p /usr/src/ocserv
tar -xf /usr/src/ocserv-${OCSERV_VERSION}.tar.xz -C /usr/src/ocserv --strip-components=1
rm -f /usr/src/ocserv-${OCSERV_VERSION}.tar.xz /usr/src/ocserv-${OCSERV_VERSION}.tar.xz.sig

#
# Compile ocserv
#
cd /usr/src/ocserv
meson setup builddir \
	--buildtype=release \
	--default-library=static \
	--prefer-static \
	-Dc_link_args="-static -lncurses" \
	-Dgssapi=disabled \
	-Dkerberos-tests=false \
	-Dlibwrap=disabled \
	-Dlocal-pcl=true \
	-Dlocal-protobuf=true \
	-Dlocal-talloc=true \
	-Dlz4=enabled \
	-Dmaxmind=disabled \
	-Dpager='' \
	-Dradius=disabled \
	-Droot-tests=false \
	-Dtun-tests=false \
	-Dutmp=disabled

meson compile -C builddir
meson install -C builddir --strip
file /usr/local/sbin/ocserv
/usr/local/sbin/ocserv -v

EOF

COPY --link ["scratchfs", "/scratchfs"]

RUN	<<EOF

set -euo pipefail
set -x

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
