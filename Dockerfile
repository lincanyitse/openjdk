FROM debian:stable-slim

ARG java_type="jdk"
ARG java_url="https://github.com/adoptium/temurin8-binaries/releases/download"
ARG SOURCES_URL="mirrors.ustc.edu.cn"
ARG version="8u412"
ARG version_suffix="b08"
ARG is_install=0
ENV APT_SOURCES_URL=${SOURCES_URL}

RUN set -eux && \
    if [ -f '/etc/apt/sources.list' ];then sed -i "s/\w\+.debian.org/${APT_SOURCES_URL}/g" /etc/apt/sources.list; \
    elif [ -f '/etc/apt/sources.list.d/debian.sources' ];then sed -i "s/\w\+.debian.org/${APT_SOURCES_URL}/g" /etc/apt/sources.list.d/debian.sources; \
    fi; \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    p11-kit \
    fontconfig \
    libfreetype6 \
    libatomic1 \
    tzdata \
    locales \
    ttf-wqy-zenhei >/dev/null && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_TYPE ${java_type}
ENV JAVA_URL ${java_url}
ENV JAVA_HOME /usr/lib/java/default-java
ENV JRE_HOME ${JAVA_HOME}
ENV PATH ${JAVA_HOME}/bin:${PATH}

ENV LANG C.UTF-8

ENV JAVA_VERSION ${version}
ENV JAVA_VERSION_SUFFIX ${version_suffix}

ENV TZ="Asia/Shanghai"

COPY docker-entrypoint.sh /
COPY docker-entrypoint.d /docker-entrypoint.d
RUN chmod +x /docker-entrypoint.sh /docker-entrypoint.d/* && \
    if [ ${is_install} -eq 1 ];then /docker-entrypoint.d/10-check-jvm.sh;fi

ENTRYPOINT ["/docker-entrypoint.sh"]

CMD ["java","-version"]
