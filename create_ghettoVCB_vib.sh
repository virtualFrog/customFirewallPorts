#!/bin/bash

set -euo pipefail

CUSTOM_VIB_TEMP_DIR=/tmp/vib-temp-$$
CUSTOM_VIB_NAME=customfirewall
CUSTOM_VIB_FILE_OFFLINE_BUNDLE_NAME=customfirewall-offline-bundle.zip
CUSTOM_VIB_VERSION="1.0.1"
CUSTOM_VIB_VENDOR="soulTec"
CUSTOM_VIB_VENDOR_URL="https://soulTec.ch"
CUSTOM_VIB_SUMMARY="Opens a specified Port for outgoing connections"
CUSTOM_VIB_DESCRIPTION="Creates a new firewall rule to enable outgoing connections"
CUSTOM_VIB_BUILD_DATE=$(date '+%Y-%m-%dT%H:%I:%S')
CUSTOM_VIB_ESXI_COMPAT=8
CUSTOM_VIB_FIREWALL_PORT=51402

# clean up any prior builds
CUSTOM_VIB_FILE_NAME=${CUSTOM_VIB_NAME}.vib
rm -f ${CUSTOM_VIB_FILE_NAME}

# Setting up VIB spec confs
VIB_DESC_FILE=${CUSTOM_VIB_TEMP_DIR}/descriptor.xml
VIB_PAYLOAD_DIR=${CUSTOM_VIB_TEMP_DIR}/payloads/payload1

# Create VIB temp & spec payload directory
mkdir -p ${CUSTOM_VIB_TEMP_DIR}
mkdir -p ${VIB_PAYLOAD_DIR}

# Create ESXi folder structure for file(s) placement
CUSTOM_VIB_BIN_DIR=${VIB_PAYLOAD_DIR}/etc/vmware/firewall
mkdir -p ${CUSTOM_VIB_BIN_DIR}

cat > ${CUSTOM_VIB_BIN_DIR}/customfirewall.xml <<EOM
<!-- Firewall configuration information for custom firewall port -->
<ConfigRoot>
<service>
<id>${CUSTOM_VIB_NAME}</id>
<rule id='0000'>
<direction>outbound</direction>
<protocol>tcp</protocol>
<porttype>dst</porttype>
<port>${CUSTOM_VIB_FIREWALL_PORT}</port>
</rule>
<enabled>true</enabled>
<required>false</required>
</service>
</ConfigRoot>
EOM


# Copy file(s) to destination folder
#cp ipmitool ${CUSTOM_VIB_BIN_DIR}

# Create tgz with payload
tar czf ${CUSTOM_VIB_TEMP_DIR}/payload1 -C ${VIB_PAYLOAD_DIR} etc

# Calculate payload size/hash
PAYLOAD_FILES=$(tar tf ${CUSTOM_VIB_TEMP_DIR}/payload1 | grep -v -E '/$' | sed -e 's/^/    <file>/' -e 's/$/<\/file>/')
PAYLOAD_SIZE=$(stat -c %s ${CUSTOM_VIB_TEMP_DIR}/payload1)
PAYLOAD_SHA256=$(sha256sum ${CUSTOM_VIB_TEMP_DIR}/payload1 | awk '{print $1}')
PAYLOAD_SHA256_ZCAT=$(zcat ${CUSTOM_VIB_TEMP_DIR}/payload1 | sha256sum | awk '{print $1}')
PAYLOAD_SHA1_ZCAT=$(zcat ${CUSTOM_VIB_TEMP_DIR}/payload1 | sha1sum | awk '{print $1}')

# Create descriptor.xml
cat > ${VIB_DESC_FILE} << __VIB_DESC__
<vib version="5.0">
  <type>bootbank</type>
  <name>${CUSTOM_VIB_NAME}</name>
  <version>${CUSTOM_VIB_VERSION}</version>
  <vendor>${CUSTOM_VIB_VENDOR}</vendor>
  <summary>${CUSTOM_VIB_SUMMARY}</summary>
  <description>${CUSTOM_VIB_DESCRIPTION}</description>
  <release-date>${CUSTOM_VIB_BUILD_DATE}</release-date>
  <urls>
    <url key="website">${CUSTOM_VIB_VENDOR_URL}</url>
  </urls>
  <relationships>
    <depends>
    </depends>
    <conflicts/>
    <replaces/>
    <provides/>
    <compatibleWith/>
  </relationships>
  <software-tags>
  </software-tags>
  <system-requires>
    <maintenance-mode>false</maintenance-mode>
    <softwarePlatform version="${CUSTOM_VIB_ESXI_COMPAT}.*" locale="" productLineID="embeddedEsx" />
  </system-requires>
  <file-list>
${PAYLOAD_FILES}
  </file-list>
  <acceptance-level>community</acceptance-level>
  <live-install-allowed>true</live-install-allowed>
  <live-remove-allowed>true</live-remove-allowed>
  <cimom-restart>false</cimom-restart>
  <stateless-ready>true</stateless-ready>
  <overlay>false</overlay>
  <payloads>
    <payload name="payload1" type="tgz" size="${PAYLOAD_SIZE}">
        <checksum checksum-type="sha-256">${PAYLOAD_SHA256}</checksum>
        <checksum checksum-type="sha-256" verify-process="gunzip">${PAYLOAD_SHA256_ZCAT}</checksum>
        <checksum checksum-type="sha-1" verify-process="gunzip">${PAYLOAD_SHA1_ZCAT}</checksum>
    </payload>
  </payloads>
</vib>
__VIB_DESC__

# Create VIB using ar utility
touch ${CUSTOM_VIB_TEMP_DIR}/sig.pkcs7
ar r ${CUSTOM_VIB_FILE_NAME} ${VIB_DESC_FILE} ${CUSTOM_VIB_TEMP_DIR}/sig.pkcs7 ${CUSTOM_VIB_TEMP_DIR}/payload1

# Create offline bundle
PYTHONPATH=/opt/vmware/vibtools-6.0.0-847598/bin python -c "import vibauthorImpl; vibauthorImpl.CreateOfflineBundle(\"${CUSTOM_VIB_FILE_NAME}\", \"${CUSTOM_VIB_FILE_OFFLINE_BUNDLE_NAME}\", True)"

# Show details of VIB that was just created
vibauthor -i -v ${CUSTOM_VIB_FILE_NAME}