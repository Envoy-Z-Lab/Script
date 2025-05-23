#!/bin/bash

set -euo pipefail

if [[ $# -eq 0 ]] || [[ "$1" == "-h" ]]; then
    echo "This script downgrades Audio Policy Manager config file"
    echo "from version 7.0 to a format compatible with 6.0 XSD schema."
    echo
    echo "USAGE: $0 [APM_XML_FILE]"
    echo
    echo "Example: $0 device/generic/goldfish/audio/policy/audio_policy_configuration.xml"
    exit 0
fi

readonly HAL_DIRECTORY=hardware/interfaces/audio
readonly SHARED_CONFIGS_DIRECTORY=frameworks/av/services/audiopolicy/config
readonly NEW_VERSION=7.0
readonly OLD_VERSION=6.0
readonly NEW_VERSION_UNDERSCORE=7_0
readonly OLD_VERSION_UNDERSCORE=6_0

readonly SOURCE_CONFIG=${ANDROID_BUILD_TOP}/$1
readonly BASENAME=$(basename "$SOURCE_CONFIG")
readonly EXPECTED_NAME="audio_policy_configuration.xml"

if [[ "$BASENAME" != "$EXPECTED_NAME" ]]; then
    echo "Error: Only $EXPECTED_NAME is supported for downgrade."
    exit 1
fi

# Validate against the 7.0 schema
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

echo "Will downgrade $1 only. Included files will not be modified."
echo "Press Ctrl-C to cancel, Enter to continue"
read

# Downgrade version in root config
sed -i -r -e 's/(audioPolicyConfiguration version=")7.0/\11.0/' ${SOURCE_CONFIG}

# Replace space-separated values with 6.0 separators
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

# Revert include references from _7_0 to _6_0
sed -i -r "s/_${NEW_VERSION_UNDERSCORE}\.xml/_${OLD_VERSION_UNDERSCORE}.xml/g" ${SOURCE_CONFIG}

# Validate against the 6.0 schema
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
echo "Downgrade of $EXPECTED_NAME complete. Please verify the result."
