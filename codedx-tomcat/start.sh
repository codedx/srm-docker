#!/usr/bin/env bash
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

# Check license file for contents
if [ ! -s /opt/codedx/license.lic ]
then
	# Remove empty license file
	rm /opt/codedx/license.lic
fi

# Set up configuration file if none is found
if [ ! -f /opt/codedx/codedx.props ]
then
	edit_config
	mv templates/codedx.props /opt/codedx/codedx.props
fi
cp templates/logback.xml.base /opt/codedx/logback.xml

# Extract Code Dx WAR for later upgrade or installation
echo "Uzipping war for codedx..."
mkdir /usr/local/tomcat/webapps/codedx
cd /usr/local/tomcat/webapps/codedx
unzip -qq ../codedx.war
cd ../

# Determine whether to install or upgrade code dx
if [ ! -e /opt/codedx/log-files ]
then
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
	java "$@" -cp /usr/local/tomcat/webapps/codedx/WEB-INF/lib/*:/usr/local/tomcat/webapps/codedx/WEB-INF/classes/ com.avi.codedx.installer.Install appdata=$CODEDX_APPDATA superuser-name=$SUPERUSER_NAME superuser-pass=$SUPERUSER_PASSWORD
	echo $?
else
	echo "Running upgrade command..."
	java "$@" -cp /usr/local/tomcat/webapps/codedx/WEB-INF/lib/*:/usr/local/tomcat/webapps/codedx/WEB-INF/classes/ com.avi.codedx.installer.Update appdata=$CODEDX_APPDATA
fi

# Start tomcat
cd /usr/local/tomcat/bin
./catalina.sh run
