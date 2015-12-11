source 'https://rubygems.org'
# if there is a super emergency and rubygems is playing up, try
#source 'http://production.cf.rubygems.org'

def rails_master?
  ENV["RAILS_MASTER"] == '1'
end

if rails_master?
  gem 'arel', git: 'https://github.com/rails/arel.git'
  gem 'rails', git: 'https://github.com/rails/rails.git'
  gem 'rails-observers', git: 'https://github.com/rails/rails-observers.git'
  gem 'seed-fu', git: 'https://github.com/SamSaffron/seed-fu.git', branch: 'discourse'
else
  gem 'rails', '~> 4.2'
  gem 'rails-observers'
  gem 'seed-fu', '~> 2.3.5'
end

gem 'mail'
gem 'mime-types', require: 'mime/types/columnar'

#gem 'redis-rails'
gem 'hiredis'
gem 'redis', require:  ["redis", "redis/connection/hiredis"]

gem 'active_model_serializers', '~> 0.8.3'

gem 'onebox'

gem 'ember-rails'
gem 'ember-source', '1.12.1'
gem 'barber'
gem 'babel-transpiler'

gem 'message_bus'

gem 'rails_multisite'

gem 'fast_xs'

gem 'fast_xor'

# while we sort out https://github.com/sdsykes/fastimage/pull/46
gem 'fastimage_discourse', require: 'fastimage'
gem 'aws-sdk', require: false
gem 'excon', require: false
gem 'unf', require: false

gem 'discourse_email_parser'

# note: for image_optim to correctly work you need to follow
# https://github.com/toy/image_optim
# pinned due to https://github.com/toy/image_optim/pull/75, docker image must be upgraded to upgrade
gem 'image_optim', '0.20.2'
gem 'multi_json'
gem 'mustache'
gem 'nokogiri'
gem 'omniauth'
gem 'omniauth-openid'
gem 'openid-redis-store'
gem 'omniauth-facebook'
gem 'omniauth-twitter'

# forked while https://github.com/intridea/omniauth-github/pull/41 is being upstreamd
gem 'omniauth-github-discourse', require: 'omniauth-github'

gem 'omniauth-oauth2', require: false
gem 'omniauth-google-oauth2'
gem 'oj'
gem 'pg'
gem 'pry-rails', require: false
gem 'r2', '~> 0.2.5', require: false
gem 'rake'


gem 'rest-client'
gem 'rinku'
gem 'sanitize'
gem 'sass'
gem 'sidekiq'
gem 'sidekiq-statistic'

# for sidekiq web
gem 'sinatra', require: false

gem 'therubyracer'
gem 'thin', require: false
gem 'highline', require: false
gem 'rack-protection' # security

# Gems used only for assets and not required
# in production environments by default.
# allow everywhere for now cause we are allowing asset debugging in prd
group :assets do
  gem 'sass-rails', '~> 4.0.5'
  gem 'uglifier'
  gem 'rtlit', require: false # for css rtling
end

group :test do
  gem 'fakeweb', '~> 1.3.0', require: false
  gem 'minitest', require: false
end

group :test, :development do
  gem 'rspec', '~> 3.2.0'
  gem 'mock_redis'
  gem 'listen', '0.7.3', require: false
  gem 'certified', require: false
  # later appears to break Fabricate(:topic, category: category)
  gem 'fabrication', '2.9.8', require: false
  gem 'discourse-qunit-rails', require: 'qunit-rails'
  gem 'mocha', require: false
  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false
  gem 'rspec-rails', require: false
  gem 'shoulda', require: false
  gem 'simplecov', require: false
  gem 'timecop'
  gem 'rspec-given'
  gem 'rspec-html-matchers'
  gem 'pry-nav'
  gem 'spork-rails'
  gem 'byebug', require: ENV['RM_INFO'].nil?
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'librarian', '>= 0.0.25', require: false
  gem 'annotate'
  gem 'foreman', require: false
end

# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem 'fast_blank' #, github: "SamSaffron/fast_blank"

# this provides a very efficient lru cache
gem 'lru_redux'

gem 'htmlentities', require: false

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railties
#  we are open to it. by deferring require to the initializer we can configure discourse installs without it

gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false

gem 'unicorn', require: false
gem 'puma', require: false
gem 'rbtrace', require: false, platform: :mri

# required for feed importing and embedding
#
gem 'ruby-readability', require: false

gem 'simple-rss', require: false

gem 'gctools', require: false, platform: :mri_21

begin
  gem 'stackprof', require: false, platform: [:mri_21, :mri_22]
  gem 'memory_profiler', require: false, platform: [:mri_21, :mri_22]
rescue Bundler::GemfileError
  STDERR.puts "You are running an old version of bundler, please upgrade bundler ASAP, if you are using Discourse docker, rebuild your container."
  gem 'stackprof', require: false, platform: [:mri_21]
  gem 'memory_profiler', require: false, platform: [:mri_21]
end

gem 'rmmseg-cpp', require: false

gem 'logster'

# perftools only works on 1.9 atm
group :profile do
  # travis refuses to install this, instead of fuffing, just avoid it for now
  #
  # if you need to profile, uncomment out this line
  # gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', platform: :mri_19
end
