#!/bin/sh
set -xe

# TODO: Referenciar ao projeto kartza/geoserver
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

# TODO: Levar parte desse código para o Dockerfile (Baixar as extensões para a imagem)
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

# Registrar arquivos de fonte
# TODO: Verificar a mensagem 
# WARN [geotools.styling] - can't parse ttf://{font-file} as a java resource present in the classpath
echo "Registering font files:"

if [ -n "$GEOSERVER_EXTRA_FONTS_DIR" ]; then 
    if [ -d "$GEOSERVER_EXTRA_FONTS_DIR" ]; then 

        JAVA_FONT_DIR=$JAVA_HOME/lib/fonts

        if [ ! -d "$JAVA_FONT_DIR" ]; then
            mkdir -p $JAVA_FONT_DIR
        fi

        find $GEOSERVER_EXTRA_FONTS_DIR -regextype posix-extended -iregex '^.*\.(t|o)tf$' -exec cp {} $JAVA_FONT_DIR \;
        chown -R root:root $JAVA_FONT_DIR
        chmod -R 644 $JAVA_FONT_DIR

        unset JAVA_FONT_DIR

    else        
        echo "Directory not exists... Skipping"
    fi 
fi

#fc-cache -f -v

echo "Finished!"

exec "$@"
