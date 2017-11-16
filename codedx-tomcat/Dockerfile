FROM tomcat

USER root
RUN mkdir /opt/codedx
ENV CODEDX_APPDATA=/opt/codedx
WORKDIR /usr/local/tomcat/webapps
COPY codedx/codedx.war .
WORKDIR /opt/codedx
COPY codedx/codedx.props .
COPY codedx/logback.xml .
VOLUME ["/opt/codedx"]
EXPOSE 8080
CMD ["catalina.sh", "run"]
