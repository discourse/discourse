source 'https://rubygems.org'

gem 'redis'
gem 'redis-rails'
gem 'hiredis'
gem 'em-redis'
gem 'rails'
gem 'pg'
gem 'sass'
gem 'rake'
# errbit is broken with 3.1.3 for now
gem 'airbrake', "3.1.2"
gem 'rest-client'
gem 'rails3_acts_as_paranoid', "~>0.2.0"
gem 'activerecord-postgres-hstore'
gem 'sidekiq'
gem 'fastimage'
gem 'nokogiri'
gem 'seed-fu'
gem 'sanitize'

gem 'sinatra', :require => nil
gem 'clockwork', :require => false

gem 'i18n-js'
# gem 'rack-mini-profiler', '0.1.21'
# gem 'rack-mini-profiler', :path => '/home/sam/Source/MiniProfiler'
gem 'rack-mini-profiler', :git => 'git://github.com/SamSaffron/MiniProfiler'
gem 'oauth', :require => false
gem 'fast_xs'
gem 'pbkdf2'
gem 'simple_handlebars_rails', path: 'vendor/gems/simple_handlebars_rails'

# Gem that enables support for plugins. It is required
gem 'discourse_plugin', path: 'vendor/gems/discourse_plugin'

# Discourse Plugins (optional)
# Polls and Tasks have been disabled for launch, we need think all sorts of stuff through before adding them back in
#   biggest concern is core support for custom sort orders, but there is also styling that just gets mishmashed into our core theme. 
# gem 'discourse_poll', path: 'vendor/gems/discourse_poll'
gem 'discourse_emoji', path: 'vendor/gems/discourse_emoji'
# gem 'discourse_task', path: 'vendor/gems/discourse_task'

gem 'rails_multisite', path: 'vendor/gems/rails_multisite'
gem 'message_bus', path: 'vendor/gems/message_bus'

gem 'koala', :require => false
gem 'multi_json'
gem 'oj'
gem 'eventmachine'
gem 'thin'

gem "active_model_serializers", :git => "git://github.com/rails-api/active_model_serializers.git"
gem 'has_ip_address'

gem 'vestal_versions', :git => 'git://github.com/zhangyuan/vestal_versions'

gem 'fog', :require => false

# Gems used only for assets and not required
# in production environments by default.
# allow everywhere for now cause we are allowing asset debugging in prd
group :assets do
  gem 'sass'
  gem 'sass-rails'
  gem 'coffee-rails'
  gem 'uglifier'
  # gem "asset_sync"
  gem 'turbo-sprockets-rails3'
  # need this to compile coffee on the fly 
  gem 'coffee-script'
end

gem 'hpricot'
gem 'jquery-rails'

gem "ember-rails", :git => 'git://github.com/emberjs/ember-rails.git' # so we get the pre version
gem 'mustache'
gem 'therubyracer', :require => 'v8'
gem 'rinku'


gem 'ruby-openid', :require => 'openid'

group :test, :development do
  # Pretty printed test output
  gem 'rspec-rails'
  gem 'shoulda'
  #gem 'turn', :require => false
  gem 'jasminerice'
  gem 'fabrication'
  gem 'guard-jasmine'
  gem 'guard-rspec' 
  gem 'guard-spork'
  gem 'mocha', :require => false
  gem 'simplecov', :require => false
  gem 'image_optim'
  gem 'certified'
  gem 'rb-fsevent'
  gem 'rb-inotify', :require => RUBY_PLATFORM.include?('linux') && 'rb-inotify'
  gem 'terminal-notifier-guard', :require => RUBY_PLATFORM.include?('darwin') && 'terminal-notifier-guard'
end

group :development do 
  gem 'pry-rails'
  gem 'better_errors'
  gem 'binding_of_caller' # I tried adding this and got an occational crash
end

# gem 'stacktrace', :require => false
