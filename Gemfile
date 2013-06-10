source 'https://rubygems.org'

gem 'active_model_serializers', git: 'https://github.com/rails-api/active_model_serializers.git'

# we had issues with latest, stick to the rev till we figure this out
# PR that makes it all hang together welcome
gem 'ember-rails', git: 'https://github.com/emberjs/ember-rails.git', ref: '57bbe32'
gem 'barber', '0.3.0'

gem 'vestal_versions', git: 'https://github.com/zhangyuan/vestal_versions'

gem 'message_bus', git: 'https://github.com/SamSaffron/message_bus'
gem 'rails_multisite', path: 'vendor/gems/rails_multisite'
gem 'simple_handlebars_rails', path: 'vendor/gems/simple_handlebars_rails'

gem 'redcarpet', require: false
gem 'activerecord-postgres-hstore'
gem 'active_attr' # until we get ActiveModel::Model with Rails 4
gem 'airbrake', '3.1.2', require: false # errbit is broken with 3.1.3 for now
gem 'clockwork', require: false
gem 'em-redis'
gem 'eventmachine'
gem 'fast_xs'
gem 'fast_xor', git: 'https://github.com/CodeMonkeySteve/fast_xor.git'
gem 'fastimage'
gem 'fog', require: false
gem 'has_ip_address'
gem 'hiredis'

# note: for image_optim to correctly work you need
# sudo apt-get install -y advancecomp gifsicle jpegoptim libjpeg-progs optipng pngcrush
gem 'image_optim'
# note: for image_sorcery to correctly work you need
# sudo apt-get install -y imagemagick
gem 'image_sorcery'
gem 'multi_json'
gem 'mustache'
gem 'nokogiri'
gem 'omniauth'
gem 'omniauth-openid'
gem 'openid-redis-store'
gem 'omniauth-facebook'
gem 'omniauth-twitter'
gem 'omniauth-github'
gem 'omniauth-browserid', git: 'https://github.com/callahad/omniauth-browserid.git', branch: 'observer_api'
gem 'omniauth-cas'
gem 'oj'
gem 'pg'
# we had pain with the 3.2.13 upgrade so monkey patch the security fix
# next time around we hope to upgrade
gem 'rails', '3.2.12'
gem 'rake'
gem 'redis'
gem 'redis-rails'
gem 'rest-client'
gem 'rinku'
gem 'sanitize'
gem 'sass'
gem 'seed-fu'
gem 'sidekiq'
gem 'sidekiq-failures'
gem 'sinatra', require: nil
gem 'slim'  # required for sidekiq-web
gem 'strong_parameters' # remove when we upgrade to Rails 4
gem 'therubyracer', require: 'v8'
gem 'thin'
gem 'diffy', require: false
gem 'highline', require: false

# Gem that enables support for plugins. It is required.
gem 'discourse_plugin', path: 'vendor/gems/discourse_plugin'

# Discourse Plugins (optional)
# Polls and Tasks have been disabled for launch, we need think all sorts of stuff through before adding them back in
#   biggest concern is core support for custom sort orders, but there is also styling that just gets mishmashed into our core theme.
# gem 'discourse_poll', path: 'vendor/gems/discourse_poll'
gem 'discourse_emoji', path: 'vendor/gems/discourse_emoji'
# gem 'discourse_task', path: 'vendor/gems/discourse_task'

# Gems used only for assets and not required
# in production environments by default.
# allow everywhere for now cause we are allowing asset debugging in prd
group :assets do
  gem 'sass'
  gem 'sass-rails'
  gem 'turbo-sprockets-rails3'
  gem 'uglifier'
end

group :test do
  gem 'fakeweb', '~> 1.3.0', require: false
  gem 'minitest', require: false
end

group :test, :development do
  gem 'jshint_on_rails'
  gem 'listen', require: false
  gem 'guard-jshint-on-rails', require: false
  gem 'certified', require: false
  gem 'fabrication', require: false
  gem 'guard-jasmine', require: false
  gem 'guard-rspec', require: false
  gem 'guard-spork', require: false
  gem 'jasminerice'
  gem 'mocha', require: false
  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false
  gem 'rspec-rails', require: false
  gem 'shoulda', require: false
  gem 'simplecov', require: false
  gem 'terminal-notifier-guard', require: false
  gem 'timecop'
  gem 'rspec-given'
  gem 'pry-rails'
  gem 'pry-nav'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'librarian', '>= 0.0.25', require: false
  # https://github.com/ctran/annotate_models/pull/106
  gem 'annotate', :git => 'https://github.com/SamSaffron/annotate_models.git'
end

# we are using a custom sprockets repo to work around: https://github.com/rails/rails/issues/8099#issuecomment-16137638
# REVIEW EVERY RELEASE
gem 'sprockets', git: 'https://github.com/SamSaffron/sprockets.git', branch: 'rails-compat'


# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem 'fast_blank' #, github: "SamSaffron/fast_blank"

# this provides a very efficient lru cache
gem 'lru_redux'

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railstie
#  we are open to it. by deferring require to the initializer we can configure disourse installs without it
gem 'rack-mini-profiler', require: false  # require: false #, git: 'git://github.com/SamSaffron/MiniProfiler'

# used for caching, optional
# redis-rack-cache is missing a sane expiry policy, it hogs redis
# https://github.com/jodosha/redis-store/pull/183
gem 'redis-rack-cache', git: 'https://github.com/SamSaffron/redis-rack-cache.git', require: false
gem 'rack-cache', require: false

gem 'rack-cors', require: false

# perftools only works on 1.9 atm
group :profile do
  # travis refuses to install this, instead of fuffing, just avoid it for now
  #
  # if you need to profile, uncomment out this line
  # gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', platform: :mri_19
end
