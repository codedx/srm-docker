#!/usr/bin/env bash

edit_config () {
	cp templates/codedx.props.base templates/codedx.props
	#populate db url
	if [ -z "$DB_URL" ]
	then
		SEDDBURL="swa.db.url = jdbc:mysql://codedx-db/codedx"
	else
		SEDDBURL="swa.db.url = $DB_URL"
	fi
	sed -i "s|swa.db.url =|$SEDDBURL|" templates/codedx.props
	#populate db driver
	if [ -z "$DB_DRIVER" ]
	then
		SEDDBDRIVER="swa.db.driver = com.mysql.jdbc.Driver"
	else
		SEDDBDRIVER="swa.db.driver = $DB_DRIVER"
	fi
	sed -i "s|swa.db.driver =|$SEDDBDRIVER|" templates/codedx.props
	#populate user
	if [ -z "$DB_USER" ]
	then
		SEDDBUSER="swa.db.user = root"
	else
		SEDDBUSER="swa.db.user = $DB_USER"
	fi
	sed -i "s|swa.db.user =|$SEDDBUSER|" templates/codedx.props
	#populate password
	if [ -z "$DB_PASSWORD" ]
	then
		SEDDBPASS="swa.db.password = root"
	else
		SEDDBPASS="swa.db.password = $DB_PASSWORD"
	fi
	sed -i "s|swa.db.password =|$SEDDBPASS|" templates/codedx.props
}

if [ ! -f /opt/codedx.props ]
then
	edit_config
	mv templates/codedx.props /opt/codedx/codedx.props
fi
cp templates/logback.xml.base /opt/codedx/logback.xml

if [ ! -e /opt/codedx/log-files ]
then
	echo "Uzipping war for codedx install..."
	mkdir /usr/local/tomcat/webapps/codedx
	cd /usr/local/tomcat/webapps/codedx
	unzip -qq ../codedx.war
	cd ../

	#if the user hasn't specified a root codedx user, default to root
	if [ -z "$SUPERUSER_NAME" ]
	then
		SUPERUSER_NAME="admin"
	fi

	#if the user hasn't specified a root codedx password, default to root	
	if [ -z "$SUPERUSER_PASSWORD" ]
	then
		SUPERUSER_PASSWORD="secret"
	fi
	echo "Running install command..."
	java -cp /usr/local/tomcat/webapps/codedx/WEB-INF/lib/*:/usr/local/tomcat/webapps/codedx/WEB-INF/classes/ com.avi.codedx.installer.Install appdata=$CODEDX_APPDATA superuser-name=$SUPERUSER_NAME superuser-pass=$SUPERUSER_PASSWORD
	echo $?
else
	echo "Uzipping war for codedx upgrade..."
	mkdir /usr/local/tomcat/webapps/updated-codedx
	cd /usr/local/tomcat/webapps/updated-codedx
	unzip -qq ../codedx.war
	cd ../
	echo "Running upgrade command..."
	java -cp /usr/local/tomcat/webapps/updated-codedx/WEB-INF/lib/*:/usr/local/tomcat/webapps/updated-codedx/WEB-INF/classes/ com.avi.codedx.installer.Update appdata=$CODEDX_APPDATA
	rm -rf /usr/local/tomcat/webapps/updated-codedx
fi
cd /usr/local/tomcat/bin
./catalina.sh run
