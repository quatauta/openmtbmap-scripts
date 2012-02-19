#!/bin/sh

URL_FILES="${@:-urls.txt}"

pushd "$(dirname "${0}")"

for URL_FILE in ${URL_FILES} ; do
    URL_FILE="$(realpath "${URL_FILE}")"
    aria2c --continue=false -j3 -x3 -R -i "${URL_FILE}"
done

mmv -v '*.1' '#1'
popd
