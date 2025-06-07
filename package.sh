#!/bin/sh
set -x

version=`grep OPTIO_VERSION optio.sh | head -1`
version=${version#declare#}
source /dev/stdin <<< $version
mkdir optio
cp optio.sh optio
cp optio.conf optio
cp README.md optio
cp LICENSE optio

zip -r optio-${OPTIO_VERSION}.zip optio

rm -rf optio
