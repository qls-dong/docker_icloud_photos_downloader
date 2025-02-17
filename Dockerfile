# Fix base to Alpine 3.16.1 due to:-
# Alpine 3.14 & 3.15 - Python 3.9 incompatibility introduced: AttributeError: module 'base64' has no attribute 'decodestring'
# Alpine 3.16        - Python 3.10 incompatibility introduced: ImportError: cannot import name 'Callable' from 'collections' (/usr/lib/python3.10/collections/__init__.py)
FROM alpine:3.17
MAINTAINER boredazfcuk

ENV config_dir="/config"
ENV TZ="Asia/Shanghai"
ENV user="root"
ENV user_id=0
ENV group_id=0
ENV force_gid="True"
ENV folder_structure="{:%Y/%m}"
ENV icloud_china="True"
ENV skip_check="True"
ENV download_path="/iCloud"
ENV synchronisation_interval=86400

# Container version serves no real purpose. Increment to force a container rebuild.
ARG container_version="1.0.21"
ARG apk_repo="mirrors.tuna.tsinghua.edu.cn"
ARG pypi_repo="https://pypi.tuna.tsinghua.edu.cn/simple"
ARG app_dependencies="python3 py3-pip exiftool coreutils tzdata curl py3-certifi py3-cffi py3-cryptography py3-secretstorage py3-jeepney py3-dateutil imagemagick shadow"
ARG build_dependencies="git"
# Fix tzlocal to 2.1 due to Python 3.8 being default in alpine 3.13.5+
ARG python_dependencies="pytz tzlocal==2.1 wheel"
ARG pyicloud_repo="qls-dong/pyicloud-login"
ARG app_repo="qls-dong/icloud_photos_downloader"

RUN sed -i "s/dl-cdn.alpinelinux.org/${apk_repo}/g" /etc/apk/repositories

RUN echo "$(date '+%d/%m/%Y - %H:%M:%S') | ***** BUILD STARTED FOR ICLOUDPD ${container_version} *****" && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install build dependencies" && \
    apk add --no-cache --no-progress --virtual=build-deps ${build_dependencies} && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install requirements" && \
    apk add --no-progress --no-cache ${app_dependencies} && \
    pip3 install -i ${pypi_repo} --upgrade pip && \
    pip3 install -i ${pypi_repo} --no-cache-dir ${python_dependencies}

RUN echo "Git repo updated: 1" && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clone ${pyicloud_repo}" && \
    pyicloud_temp_dir=$(mktemp -d) && \
    git clone --depth 1 -b master "https://github.com/${pyicloud_repo}" "${pyicloud_temp_dir}" && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${pyicloud_repo}" && \
    cd "${pyicloud_temp_dir}" && \
    pip3 install -i ${pypi_repo} --no-cache-dir . && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clone ${app_repo}" && \
    app_temp_dir=$(mktemp -d) && \
    git clone --depth 1 -b master "https://github.com/${app_repo}.git" "${app_temp_dir}" && \
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Install ${app_repo}" && \
    cd "${app_temp_dir}" && \
    pip3 install -i ${pypi_repo} --no-cache-dir . &&\
    echo "$(date '+%d/%m/%Y - %H:%M:%S') | Clean up" && \
    cd / && \
    rm -r "${pyicloud_temp_dir}" "${app_temp_dir}" && \
    apk del --no-progress --purge build-deps

RUN apk update
RUN apk add bash vim

COPY --chmod=0755 sync-icloud.sh /usr/local/bin/sync-icloud.sh
COPY --chmod=0755 healthcheck.sh /usr/local/bin/healthcheck.sh

HEALTHCHECK --start-period=10s --interval=1m --timeout=10s CMD /usr/local/bin/healthcheck.sh
  
VOLUME "${config_dir}"

CMD /usr/local/bin/sync-icloud.sh
