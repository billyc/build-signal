#!/bin/bash
# Based on: Jean Lucas <jean@4ray.co>

# bash strict mode - fail when things go wrong
set -euox pipefail
IFS=$'\n\t'

SRCDIR=`pwd`

# FETCH
git clone https://github.com/signalapp/Signal-Desktop.git
git clone https://github.com/signalapp/signal-zkgroup-node.git zkgroup
git clone https://github.com/signalapp/zkgroup.git libzkgroup
git clone --depth=1 --branch updates https://github.com/scottnonnenberg-signal/node-sqlcipher.git sqlcipher
wget https://github.com/atom/node-spellchecker/archive/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz

# patch sqlcipher
  cd sqlcipher
  git checkout updates
  patch -Np3 -i ../openssl-linking.patch
  cd $SRCDIR/Signal-Desktop

# fix spellchecker
  cd $SRCDIR/Signal-Desktop
  sed -r 's#("spellchecker": ").*"#\1file:'"${SRCDIR}"'/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz"#' -i package.json

# use good electron
  sed -r 's#("electron": ").*"#\1'9.0.2'"#' -i package.json

# Allow higher Node versions
  sed 's#"node": "#&>=#' -i package.json

# Select node-gyp versions with python3 support
  sed 's#"node-gyp": "5.0.3"#"node-gyp": "6.1.0"#' -i package.json
  sed 's#"resolutions": {#"resolutions": {"node-sass/node-gyp": "^6.0.0",#' -i package.json

# use locally modified sqlcipher, bc yarn install always seems to checkout things freshly on arm
  sed -r 's#("@journeyapps/sqlcipher": ").*"#\1file:../sqlcipher"#' -i package.json
  sed -r 's#("zkgroup": ").*"#\1file:../zkgroup"#' -i package.json
  sed 's#"ffi-napi": "2.4.5"#"ffi-napi": ">=2.4.7"#' -i ../zkgroup/package.json

# build zk
  cd $SRCDIR/libzkgroup
  make libzkgroup
  cp target/release/libzkgroup.so $SRCDIR/zkgroup/libzkgroup.so
  cd $SRCDIR/Signal-Desktop

# archictecture build flags
CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

# We can't read the release date from git so we use SOURCE_DATE_EPOCH instead
  patch --forward --strip=1 --input="${SRCDIR}/expire-from-source-date-epoch.patch"

cd $SRCDIR/Signal-Desktop

yarn install

export USE_SYSTEM_FPM="true"

# Gruntfile expects Git commit information which we don't have in a tarball download
# See https://github.com/signalapp/Signal-Desktop/issues/2376
# yarn generate
# yarn generate exec:build-protobuf exec:transpile concat copy:deps sass

yarn build-release --arm64 --linux

build() {
  cd $_pkgname-$pkgver
  [[ $CARCH == "aarch64"  ]] && CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

  if [[ $CARCH == 'aarch64' ]]; then
    # otherwise, it'll try to run x86_64-fpm..
    export USE_SYSTEM_FPM="true"
  fi

  # Gruntfile expects Git commit information which we don't have in a tarball download
  # See https://github.com/signalapp/Signal-Desktop/issues/2376
  yarn generate exec:build-protobuf exec:transpile concat copy:deps sass

  if [[ $CARCH == 'aarch64' ]]; then
    yarn build-release --arm64 --linux
  else
    yarn build-release --x64 --linux
  fi
}

package() {
  cd $_pkgname-$pkgver

  install -d "$pkgdir"/usr/{lib,bin}
  cp -a release/linux-arm64-unpacked/resources "$pkgdir"/usr/lib/$pkgname
  cat << EOF > "$pkgdir"/usr/bin/$pkgname
#!/bin/sh

NODE_ENV=production electron /usr/lib/$pkgname/app.asar "\$@"
EOF
  chmod +x "$pkgdir"/usr/bin/$pkgname

  install -Dm 644 ../$pkgname.desktop -t "$pkgdir/usr/share/applications"
  for i in 16 24 32 48 64 128 256 512 1024; do
    install -Dm 644 build/icons/png/${i}x${i}.png \
      "$pkgdir"/usr/share/icons/hicolor/${i}x${i}/apps/$pkgname.png
  done
}

