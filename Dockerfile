FROM centos/s2i-core-centos8:latest

# PostgreSQL image for OpenShift.
# Volumes:
#  * /var/lib/psql/data   - Database cluster for PostgreSQL
# Environment:
#  * $POSTGRESQL_USER     - Database user name
#  * $POSTGRESQL_PASSWORD - User's password
#  * $POSTGRESQL_DATABASE - Name of the database to create
#  * $POSTGRESQL_ADMIN_PASSWORD (Optional) - Password for the 'postgres'
#                           PostgreSQL administrative account

ENV POSTGRESQL_VERSION=12 \
    HOME=/var/lib/pgsql \
    PGUSER=postgres \
    APP_DATA=/opt/app-root

ENV SUMMARY="PostgreSQL is an advanced Object-Relational database management system" \
    DESCRIPTION="PostgreSQL is an advanced Object-Relational database management system (DBMS). \
The image contains the client and server programs that you'll need to \
create, run, maintain and access a PostgreSQL DBMS server."

LABEL summary="$SUMMARY" \
      description="$DESCRIPTION" \
      io.k8s.description="$DESCRIPTION" \
      io.k8s.display-name="PostgreSQL 12" \
      io.openshift.expose-services="5432:postgresql" \
      io.openshift.tags="database,postgresql,postgresql12,postgresql-12" \
      io.openshift.s2i.assemble-user="26" \
      name="rhel8/postgresql-12" \
      com.redhat.component="postgresql-12-container" \
      version="1" \
      usage="podman run -d --name postgresql_database -e POSTGRESQL_USER=user -e POSTGRESQL_PASSWORD=pass -e POSTGRESQL_DATABASE=db -p 5432:5432 rhel8/postgresql-12" \
      maintainer="SoftwareCollections.org <sclorg@redhat.com>"

EXPOSE 5432

RUN yum -y --exclude filesystem --setopt=tsflags=nodocs update && yum clean all

COPY root/usr/bin/fix-permissions /usr/libexec/fix-permissions
COPY usr/libexec/check-container /usr/libexec/check-container

# This image must forever use UID 26 for postgres user so our volumes are
# safe in the future. This should *never* change, the last test is there
# to make sure of that. 

RUN yum -y install epel-release redhat-rpm-config dnf-plugins-core && \
    yum -qy module disable postgresql && \
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    yum config-manager --set-enabled powertools && \
    yum config-manager --set-enabled pgdg12 && \
    yum clean all

#libpq-devel-13.2-1.el8.x86_64
RUN INSTALL_PKGS="bzip2 lbzip2 rsync tar gettext bind-utils nss_wrapper postgresql12-contrib postgresql12-devel postgis30_12 wget git cmake make gcc gcc-c++ libtool policycoreutils-python-utils llvm-toolset ccache clang-tools-extra php-pgsql php php-intl php-json bzip2-devel proj-devel boost-devel python3-pip python3-setuptools python36-devel expat-devel zlib-devel glibc-static libicu-devel" && \
    INSTALL_PKGS="$INSTALL_PKGS pgaudit12_10" && \
    yum -y --setopt=tsflags=nodocs install $INSTALL_PKGS && \
    rpm -V $INSTALL_PKGS && \
    yum clean all && \
    localedef -f UTF-8 -i en_US en_US.UTF-8 && \
    test "$(id postgres)" = "uid=26(postgres) gid=26(postgres) groups=26(postgres)" && \
    mkdir -p /var/lib/pgsql/data && \
    /usr/libexec/fix-permissions /var/lib/pgsql && \
    /usr/libexec/fix-permissions /var/run/postgresql

# Get prefix path and path to scripts rather than hard-code them in scripts
ENV CONTAINER_SCRIPTS_PATH=/usr/share/container-scripts/postgresql \
    ENABLED_COLLECTIONS=

COPY root /
#COPY ./s2i/bin/ $STI_SCRIPTS_PATH
COPY ./s2i/bin/ /usr/libexec/s2i/
COPY ./usr/share/container-scripts/postgresql /usr/share/container-scripts/postgresql


# Not using VOLUME statement since it's not working in OpenShift Online:
# https://github.com/sclorg/httpd-container/issues/30
# VOLUME ["/var/lib/pgsql/data"]

# {APP_DATA} needs to be accessed by postgres user while s2i assembling
# postgres user changes permissions of files in APP_DATA during assembling
RUN /usr/libexec/fix-permissions ${APP_DATA} && \
    usermod -a -G root postgres && \
    /usr/libexec/fix-permissions /usr/share/container-scripts/postgresql

ENV PATH="/usr/pgsql-12/bin/:$PATH"

RUN pip3 install psycopg2 python-dotenv psutil Jinja2 PyICU

# USER 26



# RUN pip3 install --user psycopg2 python-dotenv psutil Jinja2 PyICU

# ENV PYTHONPATH=/opt/app-root/src

# USER root

RUN wget -q https://nominatim.org/release/Nominatim-3.7.2.tar.bz2  && \ 
    tar xf Nominatim-3.7.2.tar.bz2 && \
    rm Nominatim-3.7.2.tar.bz2

RUN mkdir ./build && \
    cd ./build && \
    cmake ../Nominatim-3.7.2 && \
    make && \
    make install  && \
    /usr/libexec/fix-permissions .

USER 26

ENTRYPOINT ["container-entrypoint"]
CMD ["run-postgresql"]
