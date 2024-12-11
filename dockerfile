# ------------------------------------------------------------------------------
# Build Stage
# ------------------------------------------------------------------------------
FROM ubuntu:22.04 AS build-stage

WORKDIR /opt

# set the timezone in the container
ENV TZ=America/Chicago
ENV DEBIAN_FRONTEND="noninteractive"

# build arguments for the compile
ARG GIT_REPO=https://github.com/TrinityCore/TrinityCore.git
ARG GIT_BRANCH=3.3.5
ARG GIT_COMMIT=none

ENV BASE_DIR=/opt/wow
ENV SERVER_DIR=${BASE_DIR}/server
ENV CONF_DIR=${SERVER_DIR}/conf
ENV LOG_DIR=${SERVER_DIR}/log
ENV DATA_DIR=${SERVER_DIR}/data
ENV SERVER_BIN_DIR=${SERVER_DIR}/bin

ENV INSTALL_DIR=/opt/wow

RUN set -x \
 && echo building with arguments: \
 && echo GIT_REPO=${GIT_REPO} \
 && echo GIT_BRANCH=${GIT_BRANCH} \
 && echo GIT_COMMIT=${GIT_COMMIT}

RUN set -x \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install \
   clang \
   cmake \
   g++ \
   gcc \
   git \
   libboost-all-dev \
   libbz2-dev \
   libmariadb-dev-compat \
   libmariadb-dev \
   libncurses-dev \
   libreadline-dev \
   libssl-dev \
   make \
   mariadb-server \
   p7zip \
   tzdata \
 && update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 \
 && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang 100 \
 && rm -rf /var/lib/apt/lists/*

# building & installing core from the source (3.3.5a client)
RUN set -x \
 && cd /opt/ \
 && git clone -b ${GIT_BRANCH} ${GIT_REPO} \
 && cd TrinityCore \
 && if [ "${GIT_COMMIT}" != "none" ]; then git checkout ${GIT_COMMIT}; fi \
 && mkdir _build \
 && cd _build \
 && cmake ../ \
   -DCONF_DIR=${CONF_DIR} \
   -DCMAKE_INSTALL_PREFIX=${SERVER_DIR} \
   -DCMAKE_BUILD_TYPE=Release \
 && make -j $(nproc) \
 && make install

# ------------------------------------------------------------------------------
# Extractors Stage
# ------------------------------------------------------------------------------

FROM ubuntu:22.04 AS extractors

# set the timezone in the container
ENV TZ=America/Chicago
ENV DEBIAN_FRONTEND="noninteractive"

ENV BASE_DIR=/opt/wow
ENV SERVER_DIR=${BASE_DIR}/server
ENV CONF_DIR=${SERVER_DIR}/conf
ENV LOG_DIR=${SERVER_DIR}/log
ENV DATA_DIR=${SERVER_DIR}/data
ENV SERVER_BIN_DIR=${SERVER_DIR}/bin
ENV INSTALL_DIR=${BASE_DIR}/install
ENV CLIENT=wow_client_3.3.5a
ENV CLIENT_DIR=${INSTALL_DIR}/${CLIENT}

WORKDIR ${INSTALL_DIR}

COPY wow_client_3.3.5a.7z ${INSTALL_DIR}

RUN set -x \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install \
   libboost-filesystem-dev \
   libboost-iostreams-dev \
   libboost-locale-dev \
   libboost-program-options-dev \
   libboost-system-dev \
   libssl-dev \
   p7zip \
   tzdata \
 && rm -rf /var/lib/apt/lists/*

# extract the installation
RUN set -x \
 && cd ${INSTALL_DIR} \
 && 7zr x wow_client_3.3.5a.7z

# copy extractors over to the extractor instance
COPY --from=build-stage ${SERVER_BIN_DIR}/mapextractor ${CLIENT_DIR}/
COPY --from=build-stage ${SERVER_BIN_DIR}/mmaps_generator ${CLIENT_DIR}/
COPY --from=build-stage ${SERVER_BIN_DIR}/vmap4assembler ${CLIENT_DIR}/
COPY --from=build-stage ${SERVER_BIN_DIR}/vmap4extractor ${CLIENT_DIR}/

# extract data (for 3.3.5a client)
RUN set -x \
 && cd ${CLIENT_DIR} \
 && ./mapextractor \
 && ./vmap4extractor \
 && ./vmap4assembler Buildings vmaps \
 && ./mmaps_generator

# ------------------------------------------------------------------------------
# Instance Stage
# ------------------------------------------------------------------------------

FROM ubuntu:22.04 AS instance

# build arguments
ARG GIT_REPO=https://github.com/TrinityCore/TrinityCore.git
ARG GIT_BRANCH=3.3.5
ARG GIT_COMMIT=none

# set the timezone in the container
ENV TZ=America/Chicago
ENV DEBIAN_FRONTEND="noninteractive"

# build directories
ENV BUILD_DIR=/opt/TrinityCore

# server instance directories
ENV BASE_DIR=/opt/wow
ENV SERVER_DIR=${BASE_DIR}/server
ENV CONF_DIR=${SERVER_DIR}/conf
ENV LOG_DIR=${SERVER_DIR}/log
ENV DATA_DIR=${SERVER_DIR}/data
ENV SERVER_BIN_DIR=${SERVER_DIR}/bin

# client data directories
ENV INSTALL_DIR=${BASE_DIR}/install
ENV CLIENT=wow_client_3.3.5a
ENV CLIENT_DIR=${INSTALL_DIR}/${CLIENT}

# user properties
ENV WOW_USER=wow-admin
ENV WOW_GROUP=wow-admin
ENV WOW_PASSWORD=wow

# database properties
ENV DB_HOST=wow-sql
ENV DB_PORT=3306
ENV DB_USER=trinity
ENV DB_PASS=trinity

WORKDIR ${BASE_DIR}

RUN set -x \
 && echo building with arguments: \
 && echo GIT_REPO=${GIT_REPO} \
 && echo GIT_BRANCH=${GIT_BRANCH} \
 && echo GIT_COMMIT=${GIT_COMMIT}

RUN set -x \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install \
   libboost-filesystem-dev \
   libboost-iostreams-dev \
   libboost-locale-dev \
   libboost-program-options-dev \
   libboost-system-dev \
   libboost-thread-dev\
   libmariadb-dev-compat \
   libreadline8 \
   mariadb-client \
   screen \
   tzdata \
 && rm -rf /var/lib/apt/lists/*

# make the instance the new user, and setup folder structure
RUN set -x \
 && useradd -m ${WOW_USER} --shell=/bin/bash && echo "${WOW_USER}:${WOW_PASSWORD}" | chpasswd \
 && mkdir -p ${SERVER_BIN_DIR} \
 && mkdir -p ${DATA_DIR} \
 && mkdir -p ${CONF_DIR} \
 && mkdir -p ${LOG_DIR} \
 && chown -R ${WOW_USER}:${WOW_GROUP} /opt

# copy the server files over to the instance (keeps sql dir for auto updates)
COPY --from=build-stage --chown=${WOW_USER}:${WOW_GROUP} ${BUILD_DIR}/sql ${SERVER_DIR}/sql
COPY --from=build-stage --chown=${WOW_USER}:${WOW_GROUP} ${SERVER_BIN_DIR}/authserver ${SERVER_BIN_DIR}/authserver
COPY --from=build-stage --chown=${WOW_USER}:${WOW_GROUP} ${SERVER_BIN_DIR}/worldserver ${SERVER_BIN_DIR}/worldserver

# copy data extractions from the extraction stage
COPY --from=extractors --chown=${WOW_USER}:${WOW_GROUP} ${CLIENT_DIR}/dbc ${DATA_DIR}/dbc
COPY --from=extractors --chown=${WOW_USER}:${WOW_GROUP} ${CLIENT_DIR}/maps ${DATA_DIR}/maps
COPY --from=extractors --chown=${WOW_USER}:${WOW_GROUP} ${CLIENT_DIR}/mmaps ${DATA_DIR}/mmaps
COPY --from=extractors --chown=${WOW_USER}:${WOW_GROUP} ${CLIENT_DIR}/vmaps ${DATA_DIR}/vmaps
COPY --from=extractors --chown=${WOW_USER}:${WOW_GROUP} ${CLIENT_DIR}/Cameras ${DATA_DIR}/Cameras

# copy custom items
COPY --chown=${WOW_USER}:${WOW_GROUP} conf/authserver.conf ${CONF_DIR}/authserver.conf
COPY --chown=${WOW_USER}:${WOW_GROUP} conf/worldserver.conf ${CONF_DIR}/worldserver.conf
COPY --chown=${WOW_USER}:${WOW_GROUP} entry_point.sh ${SERVER_BIN_DIR}/entry_point.sh

# move to our user
USER ${WOW_USER}

# setup configuration
RUN set -x \
 && echo "setup configuration..."

# setup version info
RUN set -x \
 && export time_stamp=$(date +%Y%m%d) \
 && echo ${GIT_COMMIT}_${time_stamp} > wow.ver

# set available volumnes
VOLUME [ "${CONF_DIR}", "${LOG_DIR}" ]

# make our ports available
## auth server port
EXPOSE 3724/tcp
## world server port
EXPOSE 8085/tcp

WORKDIR ${SERVER_BIN_DIR}

ENTRYPOINT [ "/opt/wow/server/bin/entry_point.sh" ]
CMD [ "server" ]

# EOF
