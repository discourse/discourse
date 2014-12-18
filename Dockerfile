FROM ruby:2.1

MAINTAINER Vadim Geshel "vadim@yummly.com"

# discourse prerequisite
RUN curl http://apt.postgresql.org/pub/repos/apt/ACCC4CF8.asc | apt-key add - &&\
    apt-get -y update &&\
    apt-get -y install build-essential locales \
                       libxslt-dev libcurl4-openssl-dev \
                       libssl-dev libyaml-dev libtool \
                       libxml2-dev gawk libpq-dev \
                       pngcrush imagemagick \
                       postgresql-client &&\
    mkdir /jemalloc && cd /jemalloc &&\
      wget http://www.canonware.com/download/jemalloc/jemalloc-3.4.1.tar.bz2 &&\
      tar -xjf jemalloc-3.4.1.tar.bz2 && cd jemalloc-3.4.1 && ./configure && make &&\
      mv lib/libjemalloc.so.1 /usr/lib && cd / && rm -rf /jemalloc &&\
    /usr/sbin/locale-gen en_US &&\
    curl -sLO https://bitbucket.org/ariya/phantomjs/downloads/phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      tar -xjf phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      rm phantomjs-1.9.8-linux-x86_64.tar.bz2 &&\
      cp phantomjs-1.9.8-linux-x86_64/bin/phantomjs /bin/phantomjs &&\
      rm -fr phantomjs-1.9.8-linux-x86_64 &&\
    curl -sLO http://static.jonof.id.au/dl/kenutils/pngout-20130221-linux.tar.gz &&\
      tar -xf pngout-20130221-linux.tar.gz &&\
      rm pngout-20130221-linux.tar.gz &&\
      cp pngout-20130221-linux/x86_64/pngout /bin/pngout &&\
      rm -rf pngout-20130221-linux &&\
    apt-get install -y node-uglify &&\
    apt-get clean &&\
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* &&\
    rm -fr /usr/share/man && rm -fr /usr/share/doc

# ruby dependencies
# ADD Gemfile /opt/discourse/
# ADD Gemfile.lock /opt/discourse/
# ADD Gemfile_master.lock /opt/discourse/
# ADD vendor/gems/ /opt/discourse/vendor/

ADD . /opt/discourse

WORKDIR /opt/discourse

RUN bundle install


RUN mkdir -p /var/log && rm -rf log && ln -sf /var/log log

VOLUME ["/opt/discourse"]


# RUN RAILS_ENV=production bundle exec rake assets:precompile