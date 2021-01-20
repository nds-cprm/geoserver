#!/bin/sh
set -xe

export GEOSERVER_OPTS="-Djava.awt.headless=true -server \
       -XX:PerfDataSamplingInterval=500 -Dorg.geotools.referencing.forceXY=true \
       -XX:SoftRefLRUPolicyMSPerMB=36000  -XX:NewRatio=2 \
       -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:ParallelGCThreads=20 -XX:ConcGCThreads=5 \
       -XX:InitiatingHeapOccupancyPercent=70 -XX:+CMSClassUnloadingEnabled \
       -Dorg.geotools.shapefile.datetime=true -Dgeoserver.login.autocomplete=off \
       -DGEOSERVER_CONSOLE_DISABLED=${GEOSERVER_WEB_UI_DISABLED:-FALSE}"

# Preparare the JVM command line arguments
export JAVA_OPTS="${JAVA_OPTS} ${GEOSERVER_OPTS}"

echo "Pre-deploy configs:"
printf "Current GEOSERVER_VERSION=%s\n" $GEOSERVER_VERSION
printf "Current GEOSERVER_OPTS=%s\n" $GEOSERVER_OPTS
printf "Current GDAL_DATA=%s\n" $GDAL_DATA

# Baixa e instala as extensões oficiais do Sourceforge
GEOSERVER_WAR=$(find /usr/local/tomcat/ -name geoserver.war -print -quit)

for EXT in $(echo $GEOSERVER_PLUGINS_ENABLED | tr '[A-Z]' '[a-z]' | tr ',' '\n');
do 
    echo "Installing GS-EXT $EXT..."
    ( 
        cd /tmp
        curl -fsSL ${GEOSERVER_BASE_URL}/${GEOSERVER_VERSION}/extensions/geoserver-${GEOSERVER_VERSION}-${EXT}-plugin.zip -o $EXT.zip
        mkdir -p WEB-INF/lib
        unzip -qo -d WEB-INF/lib $EXT.zip     
        zip -rq $GEOSERVER_WAR WEB-INF/lib
        rm -rf $EXT.zip WEB-INF
    )
done

unset GEOSERVER_WAR

echo "Finished!"

exec "$@"
