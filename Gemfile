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
  rails_version = '6.1.4.1'
  gem 'actionmailer', rails_version
  gem 'actionpack', rails_version
  gem 'actionview', rails_version
  gem 'activemodel', rails_version
  gem 'activerecord', rails_version
  gem 'activesupport', rails_version
  gem 'railties', rails_version
  gem 'sprockets-rails'
end

gem 'json'

# TODO: At the moment Discourse does not work with Sprockets 4, we would need to correct internals
# This is a desired upgrade we should get to.
gem 'sprockets', '3.7.2'

# this will eventually be added to rails,
# allows us to precompile all our templates in the unicorn master
gem 'actionview_precompiler', require: false

gem 'seed-fu'

gem 'mail', git: 'https://github.com/discourse/mail.git', require: false
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

gem 'http_accept_language', require: false

# Ember related gems need to be pinned cause they control client side
# behavior, we will push these versions up when upgrading ember
gem 'discourse-ember-rails', '0.18.6', require: 'ember-rails'
gem 'discourse-ember-source', '~> 3.12.2'
gem 'ember-handlebars-template', '0.8.0'
gem 'discourse-fonts'

gem 'barber'

gem 'message_bus'

gem 'rails_multisite'

gem 'fast_xs', platform: :ruby

gem 'xorcist'

gem 'fastimage'

gem 'aws-sdk-s3', require: false
gem 'aws-sdk-sns', require: false
gem 'excon', require: false
gem 'unf', require: false

gem 'email_reply_trimmer'

gem 'image_optim'
gem 'multi_json'
gem 'mustache'
gem 'nokogiri'
gem 'loofah'
gem 'css_parser', require: false

gem 'omniauth'
gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'omniauth-github'

gem 'omniauth-oauth2', require: false

gem 'omniauth-google-oauth2'

gem 'oj'

gem 'pg'
gem 'mini_sql'
gem 'pry-rails', require: false
gem 'pry-byebug', require: false
gem 'r2', require: false
gem 'rake'

gem 'thor', require: false
gem 'diffy', require: false
gem 'rinku'
gem 'sidekiq'
gem 'mini_scheduler'

gem 'execjs', require: false
gem 'mini_racer'

gem 'highline', require: false

gem 'rack'

gem 'rack-protection' # security
gem 'cbor', require: false
gem 'cose', require: false
gem 'addressable'
gem 'json_schemer'

if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.1")
  # net-smtp, net-imap and net-pop were removed from default gems in Ruby 3.1
  gem "net-smtp", "~> 0.2.1", require: false
  gem "net-imap", "~> 0.2.1", require: false
  gem "net-pop", "~> 0.1.1", require: false
  gem "digest", "3.0.0", require: false
end

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
  gem 'mocha', require: false

  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false

  gem 'rspec-rails'

  gem 'shoulda-matchers', require: false
  gem 'rspec-html-matchers'
  gem 'byebug', require: ENV['RM_INFO'].nil?, platform: :mri
  gem "rubocop-discourse", require: false
  gem 'parallel_tests'

  gem 'rswag-specs'

  gem 'annotate'
end

group :development do
  gem 'ruby-prof', require: false, platform: :mri
  gem 'bullet', require: !!ENV['BULLET']
  gem 'better_errors', platform: :mri, require: !!ENV['BETTER_ERRORS']
  gem 'binding_of_caller'
  gem 'yaml-lint'
end

if ENV["ALLOW_DEV_POPULATE"] == "1"
  gem 'discourse_dev_assets'
  gem 'faker', "~> 2.16"
else
  group :development do
    gem 'discourse_dev_assets'
    gem 'faker', "~> 2.16"
  end
end

# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem 'fast_blank', platform: :ruby

# this provides a very efficient lru cache
gem 'lru_redux'

gem 'htmlentities', require: false

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railties
#  we are open to it. by deferring require to the initializer we can configure discourse installs without it

gem 'rack-mini-profiler', require: ['enable_rails_patches']

gem 'unicorn', require: false, platform: :ruby
gem 'puma', require: false
gem 'rbtrace', require: false, platform: :mri
gem 'gc_tracer', require: false, platform: :mri

# required for feed importing and embedding
gem 'ruby-readability', require: false

# rss gem is a bundled gem from Ruby 3 onwards
gem 'rss', require: false

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
gem 'lz4-ruby', require: false, platform: :ruby

gem 'sanitize'

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

gem 'rails_failover', require: false
