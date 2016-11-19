#!/bin/bash

#
# Usage: ./keg.sh configmap-name env-file [env-file ...]
#

put() {
    if [ "$#" != 2 ]; then exit 1; fi
    mapName=configmap; key=$1; value=`echo $2 | sed -e "s/ /:SP:/g"`
    eval map="\"\$$mapName\""
    map="`echo "$map" | sed -e "s/--$key=[^ ]*//g"` --$key=$value"
    eval $mapName="\"$map\""
}

get() {
    mapName=configmap; key=$1
    map=${!mapName}
    value="$(echo $map |sed -e "s/.*--${key}=\([^ ]*\).*/\1/" -e 's/:SP:/ /g' )"
}

keys() {
    mapName=configmap
    eval map="\"\$$mapName\""
    keys=`echo $map | sed -e "s/=[^ ]*//g" -e "s/\([ ]*\)--/\1/g"`
}

configmap_name=$1
shift
while [ "$1" != "" ]; do
    while IFS='' read -r line || [[ -n "$line" ]]; do
        if [[ $line == *"="* ]]
        then
            IFS='=' read -r k v <<< "$line"
            put ${k} ${v}
        fi
    done < "$1"
    shift
done

keys

# generates a configmap command
echo ""
echo -n "kubectl create configmap $configmap_name"
for key in ${keys}
do
    echo -n " --from-literal="
    echo -n "${key//_/-}" | tr '[:upper:]' '[:lower:]'
    get ${key}
    echo -n "=${value}"
done
echo ""
echo ""

# generates environment snippet to paste into deployment yaml
echo "        env:"
for key in ${keys}
do
    echo "          - name: ${key}"
    echo "            valueFrom:"
    echo "              configMapKeyRef:"
    echo "                name: $configmap_name"
    echo "                key: ${key//_/-}" | tr '[:upper:]' '[:lower:]'
done
echo ""
