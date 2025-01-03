# frozen_string_literal: true

source "https://rubygems.org"
# if there is a super emergency and rubygems is playing up, try
#source 'http://production.cf.rubygems.org'

gem "bootsnap", require: false, platform: :mri

gem "actionmailer", "~> 7.2.0"
gem "actionpack", "~> 7.2.0"
gem "actionview", "~> 7.2.0"
gem "activemodel", "~> 7.2.0"
gem "activerecord", "~> 7.2.0"
gem "activesupport", "~> 7.2.0"
gem "railties", "~> 7.2.0"
gem "sprockets-rails"

gem "json"

# TODO: At the moment Discourse does not work with Sprockets 4, we would need to correct internals
# We intend to drop sprockets rather than upgrade to 4.x
gem "sprockets", "~> 3.7.3"

# this will eventually be added to rails,
# allows us to precompile all our templates in the unicorn master
gem "actionview_precompiler", require: false

gem "discourse-seed-fu"

gem "mail"
gem "mini_mime"
gem "mini_suffix"

# config/initializers/006-mini_profiler.rb depends upon the RedisClient#call.
# Rework this when upgrading to redis client 5.0 and above.
gem "redis", "< 5.0"

# This is explicitly used by Sidekiq and is an optional dependency.
# We tell Sidekiq to use the namespace "sidekiq" which triggers this
# gem to be used. There is no explicit dependency in sidekiq cause
# redis namespace support is optional
# We already namespace stuff in DiscourseRedis, so we should consider
# just using a single implementation in core vs having 2 namespace implementations
gem "redis-namespace"

# NOTE: AM serializer gets a lot slower with recent updates
# we used an old branch which is the fastest one out there
# are long term goal here is to fork this gem so we have a
# better maintained living fork
gem "active_model_serializers", "~> 0.8.3"
gem "batch-loader"

gem "http_accept_language", require: false

gem "discourse-fonts", require: "discourse_fonts"

gem "message_bus"

gem "rails_multisite"

gem "fastimage"

gem "aws-sdk-s3", require: false
gem "aws-sdk-sns", require: false
gem "excon", require: false
gem "unf", require: false

gem "email_reply_trimmer"

gem "image_optim"
gem "multi_json"
gem "mustache"
gem "nokogiri"
gem "loofah"
gem "css_parser", require: false

gem "omniauth"
gem "omniauth-facebook"
gem "omniauth-twitter"
gem "omniauth-github"

gem "omniauth-oauth2", require: false

gem "omniauth-google-oauth2"

gem "oj"

gem "pg"
gem "mini_sql"
gem "pry-rails", require: false
gem "pry-byebug", require: false
gem "rtlcss", require: false
gem "messageformat-wrapper", require: false
gem "rake"

gem "thor", require: false
gem "diffy", require: false
gem "rinku"
gem "sidekiq"
gem "mini_scheduler"

gem "execjs", require: false
gem "mini_racer"

gem "highline", require: false

gem "rack"

gem "rack-protection" # security
gem "cbor", require: false
gem "cose", require: false
gem "addressable"
gem "json_schemer"

gem "net-smtp", require: false
gem "net-imap", require: false
gem "net-pop", require: false
gem "digest", require: false

# Gems used only for assets and not required in production environments by default.
# Allow everywhere for now cause we are allowing asset debugging in production
group :assets do
  gem "uglifier"
end

group :test do
  gem "capybara", require: false
  gem "webmock", require: false
  gem "fakeweb", require: false
  gem "simplecov", require: false
  gem "selenium-webdriver", "~> 4.14", require: false
  gem "selenium-devtools", require: false
  gem "test-prof"
  gem "rails-dom-testing", require: false
  gem "minio_runner", require: false
end

group :test, :development do
  gem "rspec"
  gem "listen", require: false
  gem "certified", require: false
  gem "fabrication", require: false
  gem "mocha", require: false

  gem "rb-fsevent", require: RUBY_PLATFORM =~ /darwin/i ? "rb-fsevent" : false

  gem "rspec-rails"

  gem "shoulda-matchers", require: false
  gem "rspec-html-matchers"
  gem "pry-stack_explorer", require: false
  gem "byebug", require: ENV["RM_INFO"].nil?, platform: :mri
  gem "rubocop-discourse", require: false
  gem "parallel_tests"

  gem "rswag-specs"

  gem "annotate"

  gem "syntax_tree"
  gem "syntax_tree-disable_ternary"

  gem "rspec-multi-mock"
end

group :development do
  gem "ruby-prof", require: false, platform: :mri
  gem "bullet", require: !!ENV["BULLET"]
  gem "better_errors", platform: :mri, require: !!ENV["BETTER_ERRORS"]
  gem "binding_of_caller"
  gem "yaml-lint"
  gem "yard"
end

if ENV["ALLOW_DEV_POPULATE"] == "1"
  gem "discourse_dev_assets"
  gem "faker", "~> 2.16"
else
  group :development, :test do
    gem "discourse_dev_assets"
    gem "faker", "~> 2.16"
  end
end

# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem "fast_blank", platform: :ruby

# this provides a very efficient lru cache
gem "lru_redux"

gem "htmlentities", require: false

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railties
#  we are open to it. by deferring require to the initializer we can configure discourse installs without it

gem "rack-mini-profiler", require: ["enable_rails_patches"]

gem "unicorn", require: false, platform: :ruby
gem "puma", require: false

gem "rbtrace", require: false, platform: :mri

# required for feed importing and embedding
gem "ruby-readability", require: false

# rss gem is a bundled gem from Ruby 3 onwards
gem "rss", require: false

gem "stackprof", require: false, platform: :mri
gem "memory_profiler", require: false, platform: :mri

gem "cppjieba_rb", require: false

gem "lograge", require: false
gem "logstash-event", require: false
gem "logster"

# A fork of sassc with dart-sass support
gem "sassc-embedded"

gem "rotp", require: false

gem "rqrcode"

gem "rubyzip", require: false

gem "sshkey", require: false

gem "rchardet", require: false
gem "lz4-ruby", require: false, platform: :ruby

gem "sanitize"

if ENV["IMPORT"] == "1"
  gem "mysql2"
  gem "redcarpet"

  # NOTE: in import mode the version of sqlite can matter a lot, so we stick it to a specific one
  gem "sqlite3", "~> 1.3", ">= 1.3.13"
  gem "ruby-bbcode-to-md", git: "https://github.com/nlalonde/ruby-bbcode-to-md"
  gem "reverse_markdown"
  gem "tiny_tds"
  gem "csv"
end

group :generic_import, optional: true do
  gem "sqlite3"
  gem "redcarpet"
end

gem "web-push"
gem "colored2", require: false
gem "maxminddb"

gem "rails_failover", require: false

gem "faraday"
gem "faraday-retry"

# workaround for faraday-net_http, see
# https://github.com/ruby/net-imap/issues/16#issuecomment-803086765
gem "net-http"

# Workaround until Ruby ships with cgi version 0.3.6 or higher.
gem "cgi", ">= 0.3.6", require: false

gem "tzinfo-data"
gem "csv", require: false

# dependencies for the automation plugin
gem "iso8601"
gem "rrule"

group :migrations, optional: true do
  gem "extralite-bundle", require: "extralite"

  # auto-loading
  gem "zeitwerk"

  # databases
  gem "trilogy"

  # CLI
  gem "ruby-progressbar"
end

gem "dry-initializer", "~> 3.1"

gem "parallel"
