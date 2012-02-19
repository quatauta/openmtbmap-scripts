#!/bin/sh

URL_FILES="${@:-urls.txt}"

pushd "$(dirname "${0}")" >/dev/null

for URL_FILE in ${URL_FILES} ; do
    wget -c -N -i "${URL_FILE}"
done

ls *.1 >/dev/null 2>&1 && mmv -v '*.1' '#1'
popd >/dev/null
