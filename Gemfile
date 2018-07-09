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
  gem 'seed-fu', git: 'https://github.com/SamSaffron/seed-fu.git', branch: 'discourse'
else
  gem 'actionmailer', '5.2'
  gem 'actionpack', '5.2'
  gem 'actionview', '5.2'
  gem 'activemodel', '5.2'
  gem 'activerecord', '5.2'
  gem 'activesupport', '5.2'
  gem 'railties', '5.2'
  gem 'sprockets-rails'
  gem 'seed-fu'
end

gem 'mail', '2.7.1.rc1', require: false
gem 'mini_mime'
gem 'mini_suffix'

gem 'hiredis'
gem 'redis', require:  ["redis", "redis/connection/hiredis"]
gem 'redis-namespace'

gem 'active_model_serializers', '~> 0.8.3'

gem 'onebox', '1.8.52'

gem 'http_accept_language', '~>2.0.5', require: false

gem 'ember-rails', '0.18.5'
gem 'ember-source', '2.13.3'
gem 'ember-handlebars-template', '0.7.5'
gem 'barber'

gem 'message_bus'

gem 'rails_multisite'

gem 'fast_xs', platform: :mri

# may move to xorcist post: https://github.com/fny/xorcist/issues/4
gem 'fast_xor', platform: :mri

gem 'fastimage'

gem 'aws-sdk-s3', require: false
gem 'excon', require: false
gem 'unf', require: false

gem 'email_reply_trimmer', '~> 0.1'

# Forked until https://github.com/toy/image_optim/pull/162 is merged
gem 'discourse_image_optim', require: 'image_optim'
gem 'multi_json'
gem 'mustache'
gem 'nokogiri'

gem 'omniauth'
gem 'omniauth-openid'
gem 'openid-redis-store'
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
gem 'r2', '~> 0.2.5', require: false
gem 'rake'

gem 'thor', require: false
gem 'rinku'
gem 'sanitize'
gem 'sidekiq'

# for sidekiq web
gem 'tilt', require: false

gem 'execjs', require: false
gem 'mini_racer'
gem 'highline', '~> 1.7.0', require: false
gem 'rack-protection' # security

# Gems used only for assets and not required in production environments by default.
# Allow everywhere for now cause we are allowing asset debugging in production
group :assets do
  gem 'uglifier'
  gem 'rtlit', require: false # for css rtling
end

group :test do
  gem 'webmock', require: false
  gem 'fakeweb', '~> 1.3.0', require: false
  gem 'minitest', require: false
end

group :test, :development do
  gem 'rspec'
  gem 'mock_redis'
  gem 'listen', require: false
  gem 'certified', require: false
  # later appears to break Fabricate(:topic, category: category)
  gem 'fabrication', require: false
  gem 'mocha', require: false
  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false
  gem 'rspec-rails', require: false
  gem 'shoulda', require: false
  gem 'rspec-html-matchers'
  gem 'pry-nav'
  gem 'byebug', require: ENV['RM_INFO'].nil?
  gem 'rubocop', require: false
end

group :development do
  gem 'ruby-prof', require: false
  gem 'bullet', require: !!ENV['BULLET']
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'annotate'
  gem 'foreman', require: false
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

gem 'sassc', require: false

gem 'rotp'
gem 'rqrcode'

gem 'sshkey', require: false

if ENV["IMPORT"] == "1"
  gem 'mysql2'
  gem 'redcarpet'
  gem 'sqlite3', '~> 1.3.13'
  gem 'ruby-bbcode-to-md', github: 'nlalonde/ruby-bbcode-to-md'
  gem 'reverse_markdown'
  gem 'tiny_tds'
end

gem 'webpush', require: false
