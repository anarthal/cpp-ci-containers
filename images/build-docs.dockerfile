#
# Copyright (c) 2019-2025 Ruben Perez Hidalgo (rubenperez038 at gmail dot com)
#
# Distributed under the Boost Software License, Version 1.0. (See accompanying
# file LICENSE_1_0.txt or copy at http://www.boost.org/LICENSE_1_0.txt)
#

FROM ubuntu:22.04

COPY boost_mysql/install_build_docs.sh /

ENV DOCBOOK_DTD_DIR=/opt/docbook-dtd
ENV DOCBOOK_XSL_DIR=/opt/docbook-xsl

RUN bash install_build_docs.sh
