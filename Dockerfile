# https://docs.geoserver.org/stable/en/user/production/java.html
# Tomcat 9 & OpenJDK 11 -> Geoserver 2.15 acima
# TODO: Verificar GDAL e JDBC nas versões 2.15 e 2.16 do GeoServer
ARG IMAGE_TOMCAT_VERSION="9-jre11-slim"
FROM tomcat:${IMAGE_TOMCAT_VERSION}

ARG GS_VERSION
ARG GS_BASE_URL="https://downloads.sourceforge.net/project/geoserver/GeoServer"

# ENV PROXY_BASE_URL=http://localhost/
ENV GEOSERVER_VERSION=${GS_VERSION}
ENV GEOSERVER_BASE_URL=${GS_BASE_URL}
ENV GEOSERVER_PLUGINS_ENABLED=""

COPY docker-entrypoint.sh /usr/local/bin

WORKDIR /tmp

# Baixa os binários do GeoServer
ADD ${GS_BASE_URL}/${GS_VERSION}/geoserver-${GS_VERSION}-war.zip geoserver.zip

# Desempacota o ZIP/WAR para fazer a instalação dos plugins
RUN set -xe && \
    # dependencias para manipular o WAR e instalar extensões
    apt-get -y update && \
    apt-get -y install --no-install-recommends zip unzip curl gdal-bin libgdal-java && \
    # Set GDAL_DATA
    export GDAL_DATA=$(dirname $(find /usr/share/ -name epsg.wkt -print -quit)) && \
    echo "export GDAL_DATA=$GDAL_DATA" >> ~/.bashrc && \
    # tornar o arquivo docker-entrypoint.sh executável
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    # Explode o ZIP para WAR
    unzip -q geoserver.zip -d geoserver/ && rm -f geoserver.zip && \
    # Extrai o WAR para mexer em alguns arquivos e inserir os plugins
    ( cd geoserver && unzip -q geoserver.war -d . && rm -f geoserver.war ) && \    
    # Remove os textos em pt-BR, que estão com problemas sérios de tradução e codificação de caracteres
    for JAR_FILE in $(ls geoserver/WEB-INF/lib/gs-web*); \
    do \
        zip -d $JAR_FILE \*pt_BR.properties; \
    done && \
    # Compacta tudo e manda para o diretóro de webapps do Tomcat
    ( cd geoserver && zip -q -r ${CATALINA_HOME}/webapps/geoserver.war * ) && \
    # Limpeza
    apt-get -y autoremove && \
    rm -rf /var/lib/apt/lists/* ./geoserver/

WORKDIR $CATALINA_HOME

ENTRYPOINT ["docker-entrypoint.sh"]

# TODO: a tag CMD está repetida pois a máquina oficial do Tomcat não tem EntryPoint 
# e a adição do mesmo fez que ela não reconhcesse o CMD legado
CMD ["catalina.sh", "run"]