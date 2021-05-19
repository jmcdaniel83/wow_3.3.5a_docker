FROM debian:10.5

RUN set -x \
 && apt-get update \
 && apt-get -y upgrade \
 && apt-get -y install \
    git \
    clang \
    cmake \
    make \
    gcc \
    g++ \
    libmariadbclient-dev \
    libssl-dev \
    libbz2-dev \
    libreadline-dev \
    libncurses-dev \
    libboost-all-dev \
    mariadb-server \
    p7zip-full \
    screen \
    libmariadb-client-lgpl-dev-compat \
 && update-alternatives --install /usr/bin/cc cc /usr/bin/clang 100 \
 && update-alternatives --install /usr/bin/c++ c++ /usr/bin/clang 100 \
 && rm -rf /var/lib/apt/lists/*

# building & installing core from the source (3.3.5a client)
RUN set -x \
 && cd /opt/ \
 && git clone -b 3.3.5 git://github.com/TrinityCore/TrinityCore.git TrinityCore.3.3.5 \
 && cd TrinityCore.3.3.5 \
 && mkdir _build \
 && cd _build \
 && cmake ../ -DCONF_DIR=/opt/wow/conf -DCMAKE_INSTALL_PREFIX=/opt/wow/server \
 && make -j $(nproc) \
 && make install \
 && mkdir /opt/wow/server/bin/logs

# remove the build directory
RUN set -x \
 && rm -fR /opt/TrinityCore.3.3.5

COPY wow_client_3.3.5a.7z /opt/wow/install/

# extract the installation
RUN set -x \
 && cd /opt/wow/install \
 && 7z x wow_client_3.3.5a.7z

# collect data (for 3.3.5a client)
RUN set -x \
 && cd /opt/wow/install/wow_client_3.3.5a \
 && /opt/wow/server/bin/mapextractor \
 && mkdir /opt/wow/server/data \
 && cp -r dbc maps /opt/wow/server/data \
 && /opt/wow/server/bin/vmap4extractor \
 && mkdir vmaps \
 && /opt/wow/server/bin/vmap4assembler Buildings vmaps \
 && cp -r vmaps /opt/wow/server/data/ \
 && mkdir mmaps \
 && /opt/wow/server/bin/mmaps_generator \
 && cp -r mmaps /opt/wow/server/data/ \
 && rm -fR /opt/wow/install

# auth server port
EXPOSE 3724
# world server port
EXPOSE 8085

WORKDIR /opt/wow

CMD [ "bash" ]

# EOF
