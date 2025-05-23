#!/bin/bash

set -euo pipefail

if (echo "$@" | grep -qe "^-h"); then
    echo "This script will downgrade Audio Policy Manager config file"
    echo "from version 7.0 to format compatible with version 6.0 XSD schema."
    echo
    echo "USAGE: $0 [APM_XML_FILE]"
    echo
    echo "Example: $0 device/generic/goldfish/audio/policy/audio_policy_configuration.xml"
    exit
fi

readonly EXPECTED_FILE_NAME="audio_policy_configuration.xml"
readonly INPUT_FILE="$1"
readonly BASENAME=$(basename "$INPUT_FILE")

if [[ "$BASENAME" != "$EXPECTED_FILE_NAME" ]]; then
    echo "Error: This script only supports modification of $EXPECTED_FILE_NAME"
    exit 1
fi

readonly HAL_DIRECTORY=hardware/interfaces/audio
readonly SHARED_CONFIGS_DIRECTORY=frameworks/av/services/audiopolicy/config
readonly NEW_VERSION=7.0
readonly OLD_VERSION=6.0

readonly SOURCE_CONFIG=${ANDROID_BUILD_TOP}/$INPUT_FILE

echo Validating the source against the $NEW_VERSION schema
xmllint --noout --xinclude \
        --nofixup-base-uris --path "$ANDROID_BUILD_TOP/$SHARED_CONFIGS_DIRECTORY" \
        --schema ${ANDROID_BUILD_TOP}/${HAL_DIRECTORY}/${NEW_VERSION}/config/audio_policy_configuration.xsd \
        ${SOURCE_CONFIG}
if [ $? -ne 0 ]; then
    echo
    echo "Config file fails validation for version $NEW_VERSION—unsafe to downgrade"
    exit 1
fi

# Update 'audioPolicyConfiguration version="7.0"' -> 1.0
sed -i -r -e 's/(audioPolicyConfiguration version=")7.0/\11.0/' ${SOURCE_CONFIG}

# Replace space-separated lists with appropriate 6.0-style separators
updateFile() {
    FILE=$1
    ATTR=$2
    SEPARATOR=$3
    SRC_LINES=$(grep -nPo "$ATTR=\"[^\"]+\"" ${FILE} || true)
    for S in $SRC_LINES; do
        R=$(echo ${S} | sed -e 's/^[0-9]\+:/\//' | sed -e "s/ /$SEPARATOR/g")
        S=$(echo ${S} | sed -e 's/:/s\//')${R}/
        echo ${S} | sed -i -f - ${FILE}
    done
}
updateFile ${SOURCE_CONFIG} "channelMasks" ","
updateFile ${SOURCE_CONFIG} "samplingRates" ","
updateFile ${SOURCE_CONFIG} "flags" "|"

# Optionally update include paths back (manual if needed)
# This assumes *_6_0.xml versions exist and the current includes end in _7_0.xml
sed -i -r 's/_7_0\.xml/_6_0.xml/g' ${SOURCE_CONFIG}

echo Validating the result against the $OLD_VERSION schema
xmllint --noout --xinclude \
        --nofixup-base-uris --path "$ANDROID_BUILD_TOP/$SHARED_CONFIGS_DIRECTORY" \
        --schema ${ANDROID_BUILD_TOP}/${HAL_DIRECTORY}/${OLD_VERSION}/config/audio_policy_configuration.xsd \
        ${SOURCE_CONFIG}
if [ $? -ne 0 ]; then
    echo
    echo "Config file fails validation for version $OLD_VERSION—please check the downgrade"
    exit 1
fi

echo
echo "Downgrade complete. Verify and test the result!"
