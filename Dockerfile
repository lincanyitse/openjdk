FROM debian:stable-slim

ARG java_type="jdk"
ARG java_url="https://github.com/adoptium/temurin8-binaries/releases/download"
ARG SOURCES_URL="mirrors.aliyun.com"
ARG version="8u392"
ARG version_suffix="b08"

RUN set -eux && \
    sed -i "s/\w\+.debian.org/${SOURCES_URL}/g" /etc/apt/sources.list.d/debian.sources && \
    apt-get update -qq && apt-get install -qqy --no-install-recommends \
    curl \
    ca-certificates \
    p11-kit \
    fontconfig libfreetype6 libatomic1 \
    locales ttf-wqy-zenhei >/dev/null && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_TYPE ${java_type}
ENV JAVA_URL ${java_url}
ENV JAVA_HOME /usr/lib/java/default-java
ENV JRE_HOME ${JAVA_HOME}
ENV PATH ${JAVA_HOME}/bin:${PATH}

ENV LANG C.UTF-8

ENV JAVA_VERSION ${version}
ENV JAVA_VERSION_SUFFIX ${version_suffix}

COPY docker-entrypoint.sh /
COPY docker-entrypoint.d /docker-entrypoint.d
RUN chmod +x /docker-entrypoint.sh /docker-entrypoint.d/*
ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["java","-version"]
