#!/bin/sh

URL_FILES="${@:-urls.txt}"

pushd "$(dirname "${0}")" >/dev/null

for URL_FILE in ${URL_FILES} ; do
    wget -N -i "${URL_FILE}"
done

ls *.1 >/dev/null 2>&1 && mmv -v '*.1' '#1'

# Unpack latest mkgmap.jar
if [ mkgmap-latest.tar.gz -nt mkgmap.jar ] ; then
    tar atf mkgmap-latest.tar.gz |
    fgrep mkgmap.jar |
    while read MKGMAP ; do
        REV="${MKGMAP#mkgmap-r}"
        REV="${REV%/*}"
        NEW="mkgmap-${REV}.jar"
        tar vaxf mkgmap-latest.tar.gz "${MKGMAP}" &&
            mv  "${MKGMAP}" "${NEW}" &&
            rm -f "mkgmap.jar" &&
            ln -sv "${NEW}" "mkgmap.jar" &&
            rm -rf mkgmap-r*/
    done
fi

popd >/dev/null
