FROM ruby:2.7.1-alpine3.12 AS base

# Env and Args

ARG DISCOURSE_VERSION="2.5.0"
ARG BUILD_DEPS="\
      sed \
      git \
      bash \
      autoconf \
      libxml2-dev \
      jhead \
      bzip2-dev \
      freetype-dev \
      jpeg-dev \
      libjpeg-turbo-utils \
      tiff-dev \
      pkgconfig \
      ghostscript \
      ghostscript-fonts \
      imagemagick \
      jpegoptim \
      libxml2 \
      nodejs \
      uglify-js \
      optipng \
      gifsicle \
      pngquant \
      build-base \
      libxml2-dev \
      libxslt-dev \
      postgresql-dev"
ARG RUNTIME_DEPS="\
      netcat-openbsd \
      sed \
      git \
      bash \
      libxml2 \
      libxslt \
      uglify-js \
      jhead \
      libbz2 \
      freetype \
      libjpeg \
      libjpeg-turbo-utils \
      tiff \
      gifsicle \
      pngquant \
      postgresql-client \
      gosu"

ARG DISCOURSE_UID=500
ARG DISCOURSE_GID=500

ARG DISCOURSE_REPOSITORY_URL="https://github.com/discourse/discourse.git"

ENV RAILS_ENV=production \
    RUBY_GC_MALLOC_LIMIT=90000000 \
    RUBY_GLOBAL_METHOD_CACHE_SIZE=131072 \
    RAILS_LOG_TO_STDOUT=true \
    RAILS_SERVE_STATIC_FILES=true \
    EXECJS_RUNTIME=Disabled \
    DISCOURSE_PORT=8080 \
    DISCOURSE_DB_HOST=postgres \
    DISCOURSE_REDIS_HOST=redis \
    DISCOURSE_SERVE_STATIC_ASSETS=true \
    DISCOURSE_UID=${DISCOURSE_UID} \
    DISCOURSE_GID=${DISCOURSE_GID} \
    DISCOURSE_REPOSITORY_URL=${DISCOURSE_REPOSITORY_URL} \
    DISCOURSE_VERSION=${DISCOURSE_VERSION} \
    BUILD_DEPS=${BUILD_DEPS} \
    RUNTIME_DEPS=${RUNTIME_DEPS}

LABEL discourse=${DISCOURSE_VERSION} \
    os="debian" \
    os.version="10" \
    name="Discourse ${DISCOURSE_VERSION}" \
    description="Discourse image" \
    maintainer="Psycho Mantys"

RUN addgroup --gid "${DISCOURSE_GID}" discourse \
 && adduser -S -D -h /app -u "${DISCOURSE_UID}" -G discourse discourse

WORKDIR /app

RUN echo "http://dl-cdn.alpinelinux.org/alpine/v$(cat /etc/alpine-release | cut -d'.' -f1,2)/community" >> /etc/apk/repositories
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories

FROM base AS build

RUN apk --update add --no-cache ${BUILD_DEPS}

RUN cd / && rm -rf /app \
 && git clone --branch v${DISCOURSE_VERSION} https://github.com/discourse/discourse.git /app

RUN git remote set-branches --add origin tests-passed \
 && sed -i 's/daemonize true/daemonize false/g' ./config/puma.rb \
 && sed -i 's;/home/discourse/discourse;/app;g' ./config/puma.rb \
 && mkdir -p "tmp/pids" "tmp/sockets" \
 && bundle config build.nokogiri --use-system-libraries \
 && bundle config set deployment 'true' \
 && bundle config set without 'test:development' \
 && bundle install \
 && bundle clean --force

FROM base

COPY --from=build /usr/local/bundle/ /usr/local/bundle/
COPY --from=build  --chown=discourse:discourse /app /app

RUN apk --update add --no-cache ${RUNTIME_DEPS}
# && find /app -not -user discourse -exec chown discourse:discourse {} \+

RUN rm -rf /usr/local/bundle/cache/*.gem \
 && find /app /usr/local/bundle -name "*.c" -delete \
 && find /app /usr/local/bundle -name "*.o" -delete \
 && rm -rf node_modules tmp/cache app/assets vendor/assets lib/assets spec \
 && rm vendor/bundle/ruby/*/cache/*.gem

COPY docker-entrypoint.sh /
COPY wait-for /

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["start"]
#CMD ["sleep"]

HEALTHCHECK --interval=1m --timeout=5s --start-period=1m \
  CMD /docker-entrypoint.sh healthcheck

