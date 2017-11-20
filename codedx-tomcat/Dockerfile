FROM tomcat

USER root
RUN mkdir /opt/codedx
ENV CODEDX_APPDATA=/opt/codedx
WORKDIR /usr/local/tomcat/webapps
COPY codedx/codedx.war .
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
