#   Copyright 2020 Code Dx, Inc
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
FROM codedx/codedx-tomcat-base:v1.0

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
COPY setenv.sh .
COPY start.sh .
RUN \
  chmod +x start.sh && \
  chown -R codedx /opt/codedx && \
  chmod o+rx /usr/local/tomcat/bin/* && \
  chmod o+r /usr/local/tomcat/bin/templates/* && \
  chmod o+rw /usr/local/tomcat/webapps /usr/local/tomcat/bin/templates /usr/local/tomcat/temp
VOLUME ["/opt/codedx"]
# Set user by ID to support non-root enforcement policies
USER 1000
WORKDIR /usr/local/tomcat/bin
EXPOSE 8080
CMD ["start.sh"]
