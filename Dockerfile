FROM alpine:3.12 AS build
RUN apk add --force-refresh \
    make \
    wget \
    perl \
    perl-app-cpanminus \
    tzdata

RUN cpanm Geo::IP && \
    cpanm Geo::IP::PurePerl

FROM crazymax/alpine-s6:3.12
LABEL mainainer="Ryan Harter <ryan@ryanharter.com>"

ENV \
  # Fail if cont-init scripts exit with non-zero code.
  S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
  CRON="" \
  PUID="" \
  PGID="" \
  TZ="" \
  HEALTHCHECK_ID="" \
  AWSTATS_ARGS=

RUN apk add --force-refresh \
      nginx \
      aws-cli \
      curl \
      perl \
      awstats \
    && rm -rf /var/cache/* \
    && mkdir /var/cache/apk

COPY --from=build /usr/local/share/perl5/site_perl /usr/local/share/perl5/site_perl
COPY --from=build /usr/share/zoneinfo /usr/share/zoneinfo

COPY root/ /
