#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

ARG BASE_IMAGE_VERSION

FROM mariadb:${BASE_IMAGE_VERSION}

ENV MYSQL_ALLOW_EMPTY_PASSWORD=1
ENV MYSQL_ROOT_PASSWORD=

COPY boost_mysql/unix-socket.cnf /etc/mysql/conf.d/
COPY boost_mysql/ssl.cnf /etc/mysql/conf.d/
COPY boost_mysql/ssl/*.pem /etc/ssl/certs/mysql/

# Custom entry point to correctly set UNIX socket permissions, even if using volumes
RUN <<EOF cat > /mariadb_entrypoint.sh
chown -R mysql:mysql /var/run/mysqld
/bin/bash /usr/local/bin/docker-entrypoint.sh mariadbd
EOF


ENTRYPOINT ["/bin/bash", "/mariadb_entrypoint.sh"]
