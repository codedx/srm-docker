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
FROM tomcat

USER root
RUN mkdir /opt/codedx
ENV CODEDX_APPDATA=/opt/codedx
WORKDIR /opt/codedx
COPY license.lic .
WORKDIR /usr/local/tomcat/webapps
RUN rm -rf *
COPY codedx.war .
WORKDIR /usr/local/tomcat/conf
COPY context.xml .
RUN mkdir /usr/local/tomcat/bin/templates
WORKDIR /usr/local/tomcat/bin/templates
COPY templates/codedx.props.base .
COPY templates/logback.xml.base .
WORKDIR /usr/local/tomcat/bin
COPY start.sh .
RUN chmod +x start.sh
VOLUME ["/opt/codedx"]
EXPOSE 8080
CMD ["start.sh"]
