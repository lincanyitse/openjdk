FROM debian:bullseye-slim

ARG JDK_TYPE="jre"
ARG JDK_URL="https://github.com/adoptium/temurin8-binaries/releases/download"
ARG SOURCES_URL="mirrors.aliyun.com"
ARG version="8u352"
ARG version_suffix="b08"

RUN set -eux \
    && sed -i "s/\w\+.debian.org/${SOURCES_URL}/g" /etc/apt/sources.list \
    && apt-get update -qq && apt-get install -qqy --no-install-recommends \
    curl \
    ca-certificates \
    p11-kit \
    fontconfig libfreetype6 libatomic1 \
    locales ttf-wqy-zenhei >/dev/null \
    && rm -rf /var/lib/apt/lists/* \
    && echo -e 'LANG="zh_CN.UTF-8"\nLANGUAGE="zh_CN:zh"' >/etc/default/locale

ENV JAVA_HOME /usr/lib/jvm/default-java
ENV JRE_HOME ${JAVA_HOME}
ENV PATH ${JAVA_HOME}/bin:${PATH}

ENV LANG C.UTF-8

ENV JAVA_VERSION ${version} 
ENV JAVA_VERSION_SUFFIX ${version_suffix}

RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
        'amd64') \
            downloadUrl=${JDK_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JDK_TYPE}_x64_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz; \
            downloadSha256="$(curl -sL ${downloadUrl}.sha256.txt|awk '{print $1}')"; \
            ;; \
        'arm64') \
            downloadUrl=${JDK_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JDK_TYPE}_aarch64_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz; \
            downloadSha256="$(curl -sL - ${downloadUrl}.sha256.txt|awk '{print $1}')"; \
            ;; \
        'armhf') \
            downloadUrl=${JDK_URL}/jdk${JAVA_VERSION}-${JAVA_VERSION_SUFFIX}/OpenJDK8U-${JDK_TYPE}_arm_linux_hotspot_${JAVA_VERSION}${JAVA_VERSION_SUFFIX}.tar.gz; \
            downloadSha256="$(curl -sL - ${downloadUrl}.sha256.txt|awk '{print $1}')"; \
            ;; \
        *) echo >&2 "error: unsupported architecture: '$arch'"; exit 1 ;;\
    esac; \
    savedAptMark="$(apt-mark showmanual)"; \
    apt-get update -qq && apt-get install -qqy --no-install-recommends wget >/dev/null && \
    rm -rf /var/lib/apt/lists/*; \
    if [ -z "$downloadSha256" ];then  downloadSha256="$(wget -qO - ${downloadUrl}.sha256.txt |awk '{print $1}')"; fi &&\
    wget --progress=dot:giga -qO openjdk.tgz "${downloadUrl}"; \
    echo "$downloadSha256 *openjdk.tgz" | sha256sum --strict --check -; \
    mkdir -p "${JAVA_HOME}"; \
    tar --extract \
        --file openjdk.tgz \
        --directory "${JAVA_HOME}" \
        --strip-components 1 \
        --no-same-owner \
    ; \
    rm openjdk.tgz*; \
    apt-mark auto '.*' >/dev/null; \
    [ -z "$savedAptMark" ] || apt-mark manual $savedAptMark >/dev/null; \
    apt-get purge -y --auto-remove -o APT::AutoRemve::RecommendsImportant=false; \
    if [ "$JDK_TYPE" = "jdk" ];then export JRE_HOME="$JAVA_HOME/jre";fi; \
    # update "cacerts" bundle to use Debian's CA certificates (and make sure it stays up-to-date with changes to Debian's store)
    # see https://github.com/docker-library/openjdk/issues/327
    #     http://rabexc.org/posts/certificates-not-working-java#comment-4099504075
    #     https://salsa.debian.org/java-team/ca-certificates-java/blob/3e51a84e9104823319abeb31f880580e46f45a98/debian/jks-keystore.hook.in
    #     https://git.alpinelinux.org/aports/tree/community/java-cacerts/APKBUILD?id=761af65f38b4570093461e6546dcf6b179d2b624#n29
    { \
		echo '#!/usr/bin/env bash'; \
		echo 'set -Eeuo pipefail'; \
		echo 'trust extract --overwrite --format=java-cacerts --filter=ca-anchors --purpose=server-auth "${JRE_HOME}/lib/security/cacerts"'; \
	} > /etc/ca-certificates/update.d/docker-openjdk; \
	chmod +x /etc/ca-certificates/update.d/docker-openjdk; \
	/etc/ca-certificates/update.d/docker-openjdk; \
	\
    # https://github.com/docker-library/openjdk/issues/331#issuecomment-498834472
	find "${JAVA_HOME}/lib" -name '*.so' -exec dirname '{}' ';' | sort -u > /etc/ld.so.conf.d/docker-openjdk.conf; \
	ldconfig; \
    # basic smoke test
	java -version

