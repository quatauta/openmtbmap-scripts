#!/bin/sh

URL_FILES="${@:-urls.txt}"

pushd "$(dirname "${0}")"

for URL_FILE in ${URL_FILES} ; do
    wget -c -N -i "${URL_FILE}"
done

mmv -v '*.1' '#1'
popd
