#   Copyright 2017 Code Dx, Inc
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
FROM tomcat:8.5.37

USER root
RUN mkdir /opt/codedx
ENV CODEDX_APPDATA=/opt/codedx
WORKDIR /opt/codedx
COPY license.lic .
WORKDIR /etc/ssl/certs/java
COPY cacerts ./cacerts-codedx
RUN CACERTS_CUSTOM=/etc/ssl/certs/java/cacerts-codedx && \
  CACERTS=/etc/ssl/certs/java/cacerts && \
  if test -s $CACERTS_CUSTOM; then cp -f $CACERTS_CUSTOM $CACERTS; fi && rm $CACERTS_CUSTOM
WORKDIR /usr/local/tomcat/webapps
RUN rm -rf *
COPY codedx.war .
RUN if test ! -s codedx.war; then \
  CODEDX_PACKAGE=codedx.war && \
  CODEDX_LATEST_ARCHIVE=codedx-latest.zip && \
  CODEDX_INSTALLERS_URL=https://codedx.com/installers && \
  CODEDX_LATEST_ARCHIVE_URL=$CODEDX_INSTALLERS_URL/$CODEDX_LATEST_ARCHIVE && \
  echo "Downloading latest $CODEDX_PACKAGE from $CODEDX_LATEST_ARCHIVE_URL..." && \
  wget -nv $CODEDX_LATEST_ARCHIVE_URL && \
  echo "Extracting $CODEDX_PACKAGE from $CODEDX_LATEST_ARCHIVE..." && \
  unzip -p $CODEDX_LATEST_ARCHIVE codedx/$CODEDX_PACKAGE > $CODEDX_PACKAGE && \
  echo "Removing $CODEDX_LATEST_ARCHIVE..." && \
  rm $CODEDX_LATEST_ARCHIVE; fi
WORKDIR /usr/local/tomcat/conf
COPY context.xml .
RUN mkdir /usr/local/tomcat/bin/templates
WORKDIR /usr/local/tomcat/bin/templates
COPY templates/codedx.props.base .
COPY templates/logback.xml.base .
WORKDIR /usr/local/tomcat/bin
COPY start.sh .

# - Install mono -
# Sources:
# - https://github.com/mono/docker/blob/d68573b0640b3e191bf41b64745a6f0683a9c17a/5.18.0.225/slim/Dockerfile
ENV MONO_VERSION 5.18.0.225

RUN apt-get update \
  && apt-get install -y --no-install-recommends gnupg dirmngr \
  && rm -rf /var/lib/apt/lists/* \
  && export GNUPGHOME="$(mktemp -d)" \
  && gpg --batch --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF \
  && gpg --batch --export --armor 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF > /etc/apt/trusted.gpg.d/mono.gpg.asc \
  && gpgconf --kill all \
  && rm -rf "$GNUPGHOME" \
  && apt-key list | grep Xamarin \
  && apt-get purge -y --auto-remove gnupg dirmngr

# (Some inclusions from https://github.com/mono/docker/blob/d68573b0640b3e191bf41b64745a6f0683a9c17a/5.18.0.225/Dockerfile)
RUN echo "deb http://download.mono-project.com/repo/debian stable-stretch/snapshots/$MONO_VERSION main" > /etc/apt/sources.list.d/mono-official-stable.list \
  && apt-get update \
  && apt-get install -y mono-runtime \
  && apt-get install -y mono-devel mono-vbnc referenceassemblies-pcl \
  && rm -rf /var/lib/apt/lists/* /tmp/*
# - End Install mono -

RUN \
  chmod +x start.sh && \
  useradd -Ms /bin/bash codedx && \
  chown -R codedx /opt/codedx && \
  chmod o+rx /usr/local/tomcat/bin/* && \
  chmod o+r /usr/local/tomcat/bin/templates/* && \
  chmod o+rw /usr/local/tomcat/webapps /usr/local/tomcat/bin/templates /usr/local/tomcat/temp
VOLUME ["/opt/codedx"]
USER codedx
WORKDIR /usr/local/tomcat/bin
EXPOSE 8080
CMD ["start.sh"]
