#!/bin/bash -e

check_java_installed() {
    if [ -z "$(which java)" ]; then
        return 1 # Java not found
    else
        return 0 # Java is installed
    fi
}

get_download_info() {
    local arch=$(dpkg --print-architecture)
    case "${JAVA_URL}" in
    *.tar.gz) downloadUrl=${JAVA_URL} ;;
    *)
        case "$arch" in
        amd64) downloadUrl=${JAVA_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JAVA_TYPE}_x64_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz ;;
        arm64) downloadUrl=${JAVA_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JAVA_TYPE}_aarch64_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz ;;
        armhf) downloadUrl=${JAVA_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JAVA_TYPE}_arm_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz ;;
        *)
            echo >&2 "error: unsupported architecture: '$arch'"
            exit 1
            ;;
        esac
        ;;
    esac
    downloadSha256=$(curl -sL "${downloadUrl}.sha256.txt" | awk '{print $1}')
}

download_and_verify() {
    if [ -z "$downloadSha256" ]; then
        downloadSha256=$(curl -fsSL "${downloadUrl}.sha256.txt" | awk '{print $1}')
    fi
    curl -fsSL -o openjdk.tgz "${downloadUrl}"
    echo "$downloadSha256 *openjdk.tgz" | sha256sum --strict --check -
}

install_java() {
    mkdir -p "${JAVA_HOME}"
    tar --extract \
        --file openjdk.tgz \
        --directory "${JAVA_HOME}" \
        --strip-components 1 \
        --no-same-owner \
        ;
    rm openjdk.tgz
    [ "$JAVA_TYPE" = "jdk" ] && export JRE_HOME="$JAVA_HOME/jre"
}

update_ca_certificates() {
    cat <<EOF >/etc/ca-certificates/update.d/docker-openjdk
#!/usr/bin/env bash
set -Eeuo pipefail
trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "\$JRE_HOME/lib/security/cacerts"
EOF
    chmod +x /etc/ca-certificates/update.d/docker-openjdk
    /etc/ca-certificates/update.d/docker-openjdk
}

configure_ld_library_path() {
    find "${JAVA_HOME}/lib" -name '*.so' -exec dirname '{}' ';' | sort -u >/etc/ld.so.conf.d/docker-openjdk.conf
    ldconfig
}

run_java_version_check() {
    java -version
}

check_java_installed || {
    get_download_info
    download_and_verify
    install_java
    update_ca_certificates
    configure_ld_library_path
    run_java_version_check
}
