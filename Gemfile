# frozen_string_literal: true

source 'https://rubygems.org'
# if there is a super emergency and rubygems is playing up, try
#source 'http://production.cf.rubygems.org'

gem 'bootsnap', require: false, platform: :mri

def rails_master?
  ENV["RAILS_MASTER"] == '1'
end

if rails_master?
  gem 'arel', git: 'https://github.com/rails/arel.git'
  gem 'rails', git: 'https://github.com/rails/rails.git'
else
  # NOTE: Until rubygems gives us optional dependencies we are stuck with this needing to be explicit
  # this allows us to include the bits of rails we use without pieces we do not.
  #
  # To issue a rails update bump the version number here
  gem 'actionmailer', '6.0.1'
  gem 'actionpack', '6.0.1'
  gem 'actionview', '6.0.1'
  gem 'activemodel', '6.0.1'
  gem 'activerecord', '6.0.1'
  gem 'activesupport', '6.0.1'
  gem 'railties', '6.0.1'
  gem 'sprockets-rails'
end

# TODO: At the moment Discourse does not work with Sprockets 4, we would need to correct internals
# This is a desired upgrade we should get to.
gem 'sprockets', '3.7.2'

# this will eventually be added to rails,
# allows us to precompile all our templates in the unicorn master
gem 'actionview_precompiler', require: false

gem 'seed-fu'

gem 'mail', require: false
gem 'mini_mime'
gem 'mini_suffix'

gem 'redis'

# This is explicitly used by Sidekiq and is an optional dependency.
# We tell Sidekiq to use the namespace "sidekiq" which triggers this
# gem to be used. There is no explicit dependency in sidekiq cause
# redis namespace support is optional
# We already namespace stuff in DiscourseRedis, so we should consider
# just using a single implementation in core vs having 2 namespace implementations
gem 'redis-namespace'

# NOTE: AM serializer gets a lot slower with recent updates
# we used an old branch which is the fastest one out there
# are long term goal here is to fork this gem so we have a
# better maintained living fork
gem 'active_model_serializers', '~> 0.8.3'

gem 'onebox'

gem 'http_accept_language', require: false

# Ember related gems need to be pinned cause they control client side
# behavior, we will push these versions up when upgrading ember
gem 'ember-rails', '0.18.5'
gem 'discourse-ember-source', '~> 3.12.2'
gem 'ember-handlebars-template', '0.8.0'

gem 'barber'

gem 'message_bus'

gem 'rails_multisite'

gem 'fast_xs', platform: :mri

# may move to xorcist post: https://github.com/fny/xorcist/issues/4
gem 'fast_xor', platform: :mri

gem 'fastimage'

gem 'aws-sdk-s3', require: false
gem 'aws-sdk-sns', require: false
gem 'excon', require: false
gem 'unf', require: false

gem 'email_reply_trimmer'

# Forked until https://github.com/toy/image_optim/pull/162 is merged
# https://github.com/discourse/image_optim
gem 'discourse_image_optim', require: 'image_optim'
gem 'multi_json'
gem 'mustache'
gem 'nokogiri'
gem 'css_parser', require: false

gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'omniauth-instagram'
gem 'omniauth-github'

gem 'omniauth-oauth2', require: false

gem 'omniauth-google-oauth2'

gem 'oj'
gem 'pg'
gem 'mini_sql'
gem 'pry-rails', require: false
gem 'r2', require: false
gem 'rake'

gem 'thor', require: false
gem 'diffy', require: false
gem 'rinku'
gem 'sanitize'
gem 'sidekiq'
gem 'mini_scheduler'

# for sidekiq web
gem 'tilt', require: false

gem 'execjs', require: false
gem 'mini_racer'

# TODO: determine why highline is being held back and upgrade to latest
gem 'highline', '~> 1.7.0', require: false

# TODO: Upgrading breaks Sidekiq Web
# This is a bit of a hornets nest cause in an ideal world we much prefer
# if Sidekiq reused session and CSRF mitigation with Discourse on the
# _forum_session cookie instead of a rack.session cookie
gem 'rack', '2.0.8'

gem 'rack-protection' # security
gem 'cbor', require: false
gem 'cose', require: false
gem 'addressable'

# Gems used only for assets and not required in production environments by default.
# Allow everywhere for now cause we are allowing asset debugging in production
group :assets do
  gem 'uglifier'
  gem 'rtlit', require: false # for css rtling
end

group :test do
  gem 'webmock', require: false
  gem 'fakeweb', require: false
  gem 'minitest', require: false
  gem 'simplecov', require: false
  gem "test-prof"
end

group :test, :development do
  gem 'rspec'
  gem 'mock_redis'
  gem 'listen', require: false
  gem 'certified', require: false
  gem 'fabrication', require: false

  # TODO: upgrading to 1.10.1 cause it breaks our test suite.
  # We want our test suite fixed though to support this upgrade.
  gem 'mocha', '1.8.0', require: false

  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false

  # TODO determine if we can update this to 0.10, API changes happened
  # we would like to upgrade it if possible
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false

  # TODO once 4.0.0 is released upgrade to it, at time of writing 3.9.0 is latest
  gem 'rspec-rails', '4.0.0.beta2', require: false

  gem 'shoulda-matchers', require: false
  gem 'rspec-html-matchers'
  gem 'pry-nav'
  gem 'byebug', require: ENV['RM_INFO'].nil?
  gem 'rubocop', require: false
  gem "rubocop-discourse", require: false
  gem 'parallel_tests'
end

group :development do
  gem 'ruby-prof', require: false
  gem 'bullet', require: !!ENV['BULLET']
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'yaml-lint'
  gem 'annotate'
end

# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem 'fast_blank', platform: :mri

# this provides a very efficient lru cache
gem 'lru_redux'

gem 'htmlentities', require: false

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railties
#  we are open to it. by deferring require to the initializer we can configure discourse installs without it

gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false

gem 'unicorn', require: false, platform: :mri
gem 'puma', require: false
gem 'rbtrace', require: false, platform: :mri
gem 'gc_tracer', require: false, platform: :mri

# required for feed importing and embedding
gem 'ruby-readability', require: false

gem 'stackprof', require: false, platform: :mri
gem 'memory_profiler', require: false, platform: :mri

gem 'cppjieba_rb', require: false

gem 'lograge', require: false
gem 'logstash-event', require: false
gem 'logstash-logger', require: false
gem 'logster'

# NOTE: later versions of sassc are causing a segfault, possibly dependent on processer architecture
# and until resolved should be locked at 2.0.1
gem 'sassc', '2.0.1', require: false
gem "sassc-rails"

gem 'rotp', require: false
gem 'rqrcode'

gem 'rubyzip', require: false

gem 'sshkey', require: false

gem 'rchardet', require: false
gem 'lz4-ruby', require: false, platform: :mri

if ENV["IMPORT"] == "1"
  gem 'mysql2'
  gem 'redcarpet'

  # NOTE: in import mode the version of sqlite can matter a lot, so we stick it to a specific one
  gem 'sqlite3', '~> 1.3', '>= 1.3.13'
  gem 'ruby-bbcode-to-md', git: 'https://github.com/nlalonde/ruby-bbcode-to-md'
  gem 'reverse_markdown'
  gem 'tiny_tds'
  gem 'csv'
end

gem 'webpush', require: false
gem 'colored2', require: false
gem 'maxminddb'
