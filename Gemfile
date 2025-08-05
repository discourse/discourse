# frozen_string_literal: true

ruby "~> 3.3"

source "https://rubygems.org"
# if there is a super emergency and rubygems is playing up, try
#source 'http://production.cf.rubygems.org'

gem "bootsnap", require: false, platform: :mri

gem "actionmailer", "~> 8.0.0"
gem "actionpack", "~> 8.0.0"
gem "actionview", "~> 8.0.0"
gem "activemodel", "~> 8.0.0"
gem "activerecord", "~> 8.0.0"
gem "activesupport", "~> 8.0.0"
gem "railties", "~> 8.0.0"

gem "propshaft"
gem "json"

# this will eventually be added to rails,
# allows us to precompile all our templates in the unicorn master
gem "actionview_precompiler", require: false

gem "discourse-seed-fu"

gem "mail"
gem "mini_mime"
gem "mini_suffix"

# NOTE: hiredis-client is recommended for high performance use of Redis
# however a recent attempt at an upgrade lead to https://meta.discourse.org/t/rebuild-error/375387
# for now we are sticking with the socked based implementation that is not sensitive to this issue
# gem "hiredis-client"
gem "redis"

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

gem "http_accept_language", require: false

gem "discourse-fonts", require: "discourse_fonts"
gem "discourse-emojis", require: "discourse_emojis"

gem "message_bus"

gem "rails_multisite"

gem "fastimage"

gem "aws-sdk-s3", require: false
gem "aws-sdk-sns", require: false
gem "aws-sdk-mediaconvert", require: false
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

gem "mini_racer"

gem "highline", require: false

# When unicorn is not used anymore, we can use Rack 3
gem "rack", "< 3"

gem "rack-protection" # security
gem "cbor", require: false
gem "cose", require: false
gem "addressable"
gem "json_schemer"

gem "net-smtp", require: false
gem "net-imap", require: false
gem "net-pop", require: false
gem "digest", require: false

gem "goldiloader", require: false

group :test do
  gem "capybara", require: false
  gem "webmock", require: false
  gem "simplecov", require: false
  gem "test-prof"
  gem "rails-dom-testing", require: false
  gem "minio_runner", require: false
  gem "capybara-playwright-driver"
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

  gem "annotaterb"

  gem "syntax_tree"

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
  gem "faker"
else
  group :development, :test do
    gem "discourse_dev_assets"
    gem "faker"
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

  # non-cryptographic hashing algorithm for generating placeholder IDs
  gem "digest-xxhash"
end

gem "dry-initializer", "~> 3.1"

gem "parallel"

# for discourse-zendesk-plugin
gem "inflection", require: false
gem "multipart-post", require: false
gem "faraday-multipart", require: false
gem "zendesk_api", require: false

# for discourse-subscriptions
gem "stripe", require: false

# for discourse-github
gem "sawyer", require: false
gem "octokit", require: false

# for discourse-ai
gem "tokenizers", require: false
gem "tiktoken_ruby", require: false
gem "discourse_ai-tokenizers", require: false
gem "ed25519" # TODO: remove this as existing ssl gem should handle this
gem "Ascii85", require: false
gem "ruby-rc4", require: false
gem "hashery", require: false
gem "ttfunk", require: false
gem "afm", require: false
gem "pdf-reader", require: false
