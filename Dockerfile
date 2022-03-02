FROM alpine:3.14

ENV  LANG=en_US.UTF-8 \
     LANGUAGE=en_US:en

ARG LIBERICA_JVM_DIR=/usr/lib/jvm
ARG LIBERICA_VERSION=17.0.1
ARG LIBERICA_ROOT=/tmp/java/jdk-${LIBERICA_VERSION}-lite
ARG PKG_URL="https://download.bell-sw.com/java/17.0.1+12/bellsoft-jdk17.0.1+12-linux-x64-musl-lite.tar.gz"

RUN mkdir -p /tmp/java \
    && wget "${PKG_URL}" -O /tmp/java/jdk.tar.gz \
    && tar xzf /tmp/java/jdk.tar.gz -C /tmp/java \
    && mkdir -pv "${LIBERICA_JVM_DIR}" \
    &&    mv $LIBERICA_ROOT /usr/lib/jvm/jdk \
    &&    rm -rf /tmp/java \
    &&    rm -rf /tmp/hsperfdata_root

ENV JAVA_HOME /usr/lib/jvm/jdk
ENV PATH /usr/lib/jvm/jdk/bin:$PATH
#RUN echo ${LIBERICA_ROOT}
RUN java -version
#RUN javac -version
# working directory for gatling

ARG MAVEN_VERSION=3.8.4
ARG USER_HOME_DIR="/root"
ARG SHA=a9b2d825eacf2e771ed5d6b0e01398589ac1bfa4171f36154d1b5787879605507802f699da6f7cfc80732a5282fd31b28e4cd6052338cbef0fa1358b48a5e3c8
ARG BASE_URL=https://apache.osuosl.org/maven/maven-3/${MAVEN_VERSION}/binaries

RUN apk add --no-cache curl tar bash procps

RUN mkdir -p /usr/share/maven /usr/share/maven/ref \
  && curl -fsSL -o /tmp/apache-maven.tar.gz ${BASE_URL}/apache-maven-${MAVEN_VERSION}-bin.tar.gz \
  && echo "${SHA}  /tmp/apache-maven.tar.gz" | sha512sum -c - \
  && tar -xzf /tmp/apache-maven.tar.gz -C /usr/share/maven --strip-components=1 \
  && rm -f /tmp/apache-maven.tar.gz \
  && ln -s /usr/share/maven/bin/mvn /usr/bin/mvn

ENV MAVEN_HOME /usr/share/maven
ENV MAVEN_CONFIG "$USER_HOME_DIR/.m2"

#WORKDIR /opt

# gating version
#ENV GATLING_VERSION 3.7.2
# create directory for gatling install
#RUN mkdir -p gatling
# install gatling
RUN apk add --update wget bash libc6-compat
#  mkdir -p /tmp/downloads && \
#  wget -q -O /tmp/downloads/gatling-$GATLING_VERSION.zip \
#  https://repo1.maven.org/maven2/io/gatling/highcharts/gatling-charts-highcharts-bundle/3.7.2/gatling-charts-highcharts-bundle-3.7.2-bundle.zip && \
#  mkdir -p /tmp/archive && cd /tmp/archive && \
#  unzip /tmp/downloads/gatling-$GATLING_VERSION.zip && \
#  mv /tmp/archive/gatling-charts-highcharts-bundle-$GATLING_VERSION/* /opt/gatling/ && \
#  rm -rf /tmp/*
COPY src ./opt/src
COPY pom.xml ./opt
# change context to gatling directory
WORKDIR  /opt

# set directories below to be mountable from host
VOLUME ["/opt/gatling/conf", "/opt/gatling/results", "/opt/gatling/user-files"]

# set environment variables
ENV PATH $PATH:/opt/gatling/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV GATLING_HOME /opt/gatling

RUN echo 'hosts: files dns' >> /etc/nsswitch.conf
RUN apk add --no-cache iputils ca-certificates net-snmp-tools procps lm_sensors tzdata su-exec libcap && \
    update-ca-certificates

ENV TELEGRAF_VERSION 1.21.2

RUN set -ex && \
    mkdir ~/.gnupg; \
    echo "disable-ipv6" >> ~/.gnupg/dirmngr.conf; \
    apk add --no-cache --virtual .build-deps wget gnupg tar && \
    for key in \
        05CE15085FC09D18E99EFB22684A14CF2582E0C5 ; \
    do \
        gpg --keyserver hkp://keyserver.ubuntu.com --recv-keys "$key" ; \
    done && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_static_linux_amd64.tar.gz.asc && \
    wget --no-verbose https://dl.influxdata.com/telegraf/releases/telegraf-${TELEGRAF_VERSION}_static_linux_amd64.tar.gz && \
    gpg --batch --verify telegraf-${TELEGRAF_VERSION}_static_linux_amd64.tar.gz.asc telegraf-${TELEGRAF_VERSION}_static_linux_amd64.tar.gz && \
    mkdir -p /usr/src /etc/telegraf && \
    tar -C /usr/src -xzf telegraf-${TELEGRAF_VERSION}_static_linux_amd64.tar.gz && \
    mv /usr/src/telegraf*/etc/telegraf/telegraf.conf /etc/telegraf/ && \
    mkdir /etc/telegraf/telegraf.d && \
    cp -a /usr/src/telegraf*/usr/bin/telegraf /usr/bin/ && \
    gpgconf --kill all && \
    rm -rf *.tar.gz* /usr/src /root/.gnupg && \
    apk del .build-deps && \
    addgroup -S telegraf && \
    adduser -S telegraf -G telegraf && \
    chown -R telegraf:telegraf /etc/telegraf && \
    cd /etc/telegraf && \
    rm -rf telegraf.conf

COPY telegraf.conf /etc/telegraf
EXPOSE 8125/udp 8092/udp 8094
ENTRYPOINT ["tail", "-f", "/dev/null"]
#ENTRYPOINT ["gatling.sh"]