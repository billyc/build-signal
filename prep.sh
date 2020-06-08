#!/bin/bash
# Based on: Jean Lucas <jean@4ray.co>

# bash strict mode - fail when things go wrong
set -euo pipefail
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
  sed -r 's#("spellchecker": ").*"#\1file:'"${srcdir}"'/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz"#' -i package.json

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
  [[ $CARCH == "aarch64"  ]] && CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

  # We can't read the release date from git so we use SOURCE_DATE_EPOCH instead
  patch --forward --strip=1 --input="${SRCDIR}/expire-from-source-date-epoch.patch"

  yarn install


source_aarch64=(
  $pkgname-$pkgver.tar.gz::https://github.com/signalapp/$_pkgname/archive/v$pkgver.tar.gz
  $pkgname.desktop
  openssl-linking.patch
  expire-from-source-date-epoch.patch
  # Cherry-pick a specific commit for the node-spellchecker dependency
  # See https://github.com/atom/node-spellchecker/issues/127
  "https://github.com/atom/node-spellchecker/archive/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz"
  "zkgroup::git+https://github.com/signalapp/signal-zkgroup-node.git"
  "libzkgroup::git+https://github.com/signalapp/zkgroup.git"
)
# can't use it directly bc git-lfs causes trouble
# "sqlcipher::git+https://github.com/scottnonnenberg-signal/node-sqlcipher.git#branch=updates"
sha512sums_aarch64=('64b7cc3c4104879f3aca7aac71adc418522baf676f37106aac16130d1873faf3eda04b68494a3b765b8de2633fc0f50dcddab504ff015ed8a026d20dc2c719a7'
                    'c5ec0bf524e527ecf94207ef6aa1f2671346e115ec15de6d063cde0960151813752a1814e003705fc1a99d4e2eae1b3ca4d03432a50790957186e240527cc361'
                    '2c10d4cc6c0b9ca650e786c1e677f22619a78c93465f27fc4cf4831f1cfe771f3b9885a416e381a9e14c3aea5d88cb3545264046188db72d54b8567266811e51'
                    '6673066172d6c367961f3e2d762dd483e51a9f733d52e27d0569b333ad397375fd41d61b8a414b8c9e8dbba560a6c710678b3d105f8d285cb94d70561368d5a2'
                    '42f57802fa91dafb6dbfb5a3f613c4c07df65e97f8da84c9a54292c97a4d170f8455461aac8f6f7819d1ffbea4bf6c28488f8950056ba988776d060be3f107dd'
                    'SKIP'
                    'SKIP')
sha512sums_x86_64=('64b7cc3c4104879f3aca7aac71adc418522baf676f37106aac16130d1873faf3eda04b68494a3b765b8de2633fc0f50dcddab504ff015ed8a026d20dc2c719a7'
                   'c5ec0bf524e527ecf94207ef6aa1f2671346e115ec15de6d063cde0960151813752a1814e003705fc1a99d4e2eae1b3ca4d03432a50790957186e240527cc361'
                   '2c10d4cc6c0b9ca650e786c1e677f22619a78c93465f27fc4cf4831f1cfe771f3b9885a416e381a9e14c3aea5d88cb3545264046188db72d54b8567266811e51'
                   '6673066172d6c367961f3e2d762dd483e51a9f733d52e27d0569b333ad397375fd41d61b8a414b8c9e8dbba560a6c710678b3d105f8d285cb94d70561368d5a2'
                   '42f57802fa91dafb6dbfb5a3f613c4c07df65e97f8da84c9a54292c97a4d170f8455461aac8f6f7819d1ffbea4bf6c28488f8950056ba988776d060be3f107dd')

prepare() {
  if [[ $CARCH == 'aarch64' ]]; then
    git clone --depth=1 --branch updates https://github.com/scottnonnenberg-signal/node-sqlcipher.git sqlcipher
    cd ${srcdir}/sqlcipher
    git checkout updates
    patch -Np3 -i ../openssl-linking.patch

    cd ${srcdir}/$_pkgname-$pkgver
  fi

  # Fix SpellChecker build with imminent Node 13
  # See https://github.com/atom/node-spellchecker/issues/127
  sed -r 's#("spellchecker": ").*"#\1file:'"${srcdir}"'/613ff91dd2d9a5ee0e86be8a3682beecc4e94887.tar.gz"#' -i package.json

  # Set system Electron version for ABI compatibility
  # 9.0.3 is not yet available, so 9.0.2 is added manually
  # sed -r 's#("electron": ").*"#\1'$(cat /usr/lib/electron/version)'"#' -i package.json
  sed -r 's#("electron": ").*"#\1'9.0.2'"#' -i package.json


  if [[ $CARCH == 'aarch64' ]]; then
    # use locally modified sqlcipher, bc yarn install always seems to checkout things freshly on arm
    sed -r 's#("@journeyapps/sqlcipher": ").*"#\1file:../sqlcipher"#' -i package.json

    sed -r 's#("zkgroup": ").*"#\1file:../zkgroup"#' -i package.json
    sed 's#"ffi-napi": "2.4.5"#"ffi-napi": ">=2.4.7"#' -i ../zkgroup/package.json

    cd ${srcdir}/libzkgroup
    make libzkgroup
    cp target/release/libzkgroup.so ${srcdir}/zkgroup/libzkgroup.so
    cd ${srcdir}/$_pkgname-$pkgver
  fi

  # Allow higher Node versions
  sed 's#"node": "#&>=#' -i package.json

  # Select node-gyp versions with python3 support
  sed 's#"node-gyp": "5.0.3"#"node-gyp": "6.1.0"#' -i package.json
  # https://github.com/sass/node-sass/pull/2841
  # https://github.com/sass/node-sass/issues/2716
  sed 's#"resolutions": {#"resolutions": {"node-sass/node-gyp": "^6.0.0",#' -i package.json

  [[ $CARCH == "aarch64"  ]] && CFLAGS=`echo $CFLAGS | sed -e 's/-march=armv8-a//'` && CXXFLAGS="$CFLAGS"

  # We can't read the release date from git so we use SOURCE_DATE_EPOCH instead
  patch --forward --strip=1 --input="${srcdir}/expire-from-source-date-epoch.patch"

  yarn install

  if [[ $CARCH == 'x86_64' ]]; then
    # Have SQLCipher dynamically link from OpenSSL
    # See https://github.com/signalapp/Signal-Desktop/issues/2634
    patch -Np1 -i ${scrdir}/openssl-linking.patch
  fi
}

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
  if [[ $CARCH == 'aarch64' ]]; then
    cp -a release/linux-arm64-unpacked/resources "$pkgdir"/usr/lib/$pkgname
  else
    cp -a release/linux-unpacked/resources "$pkgdir"/usr/lib/$pkgname
  fi
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
