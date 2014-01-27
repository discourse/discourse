source 'https://rubygems.org'

# monkey patching to support dual booting
module Bundler::SharedHelpers
  def default_lockfile=(path)
    @default_lockfile = path
  end
  def default_lockfile
    @default_lockfile ||= Pathname.new("#{default_gemfile}.lock")
  end
end

module ::Kernel
  def rails4?
    !ENV["RAILS3"]
  end

  def rails_master?
    rails4? && ENV["RAILS_MASTER"]
  end
end

if rails4?
  rails_version = rails_master? ? 'rails_master' : 'rails4'

  Bundler::SharedHelpers.default_lockfile = Pathname.new("#{Bundler::SharedHelpers.default_gemfile}_#{rails_version}.lock")

  # Bundler::Dsl.evaluate already called with an incorrect lockfile ... fix it
  class Bundler::Dsl
    # A bit messy, this can be called multiple times by bundler, avoid blowing the stack
    unless self.method_defined? :to_definition_unpatched
      alias_method :to_definition_unpatched, :to_definition
    end
    def to_definition(bad_lockfile, unlock)
      to_definition_unpatched(Bundler::SharedHelpers.default_lockfile, unlock)
    end
  end
else
  # Note to be deprecated, in place of a dual boot master
  puts "Booting in Rails 3 mode"
end

# see: https://github.com/mbleigh/seed-fu/pull/54
# taking forever to get changes upstream in seed-fu
gem 'seed-fu-discourse', require: 'seed-fu'

if rails4?
  if rails_master?
    gem 'rails', git: 'https://github.com/rails/rails.git'
    gem 'actionpack-action_caching', git: 'https://github.com/rails/actionpack-action_caching.git'
  else
    gem 'rails'
    gem 'actionpack-action_caching'
  end
  gem 'rails-observers'
else
  # we had pain with the 3.2.13 upgrade so monkey patch the security fix
  # next time around we hope to upgrade
  gem 'rails', '3.2.12'
  gem 'strong_parameters' # remove when we upgrade to Rails 4
  # we are using a custom sprockets repo to work around: https://github.com/rails/rails/issues/8099#issuecomment-16137638
  # REVIEW EVERY RELEASE
  gem 'sprockets', git: 'https://github.com/SamSaffron/sprockets.git', branch: 'rails-compat'
  gem 'activerecord-postgres-hstore'
  gem 'active_attr'
end

#gem 'redis-rails'
gem 'hiredis'
gem 'redis', :require => ["redis", "redis/connection/hiredis"]

gem 'active_model_serializers'


gem 'onebox', git: 'https://github.com/dysania/onebox.git'

# we had issues with latest, stick to the rev till we figure this out
# PR that makes it all hang together welcome
gem 'ember-rails'
gem 'ember-source', '~> 1.2.0.1'
gem 'handlebars-source', '~> 1.1.2'
gem 'barber'

gem 'message_bus'
gem 'rails_multisite', path: 'vendor/gems/rails_multisite'

gem 'redcarpet', require: false
gem 'airbrake', '3.1.2', require: false # errbit is broken with 3.1.3 for now
gem 'sidetiq', '>= 0.3.6'
gem 'eventmachine'
gem 'fast_xs'

gem 'fast_xor'
gem 'fastimage'
gem 'fog', '1.18.0', require: false
gem 'unf', require: false

# see: https://twitter.com/samsaffron/status/412360162297393152
# Massive amount of changes made in branch we use, no PR upstreamed
# We need to get this sorted
# https://github.com/samsaffron/email_reply_parser
gem 'email_reply_parser-discourse', require: 'email_reply_parser'

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
gem 'omniauth-oauth2', require: false
# abandoned gem hard to tell what is going on, multiple PRs upstream being ignored:
# https://twitter.com/samsaffron/status/412372111710109696
# we use: gem 'omniauth-browserid', git: 'https://github.com/samsaffron/omniauth-browserid.git', branch: 'observer_api'
gem 'omniauth-browserid-discourse', require: 'omniauth-browserid'
gem 'omniauth-cas'
gem 'oj'
# while resolving https://groups.google.com/forum/#!topic/ruby-pg/5_ylGmog1S4
gem 'pg', '0.15.1'
gem 'rake'


gem 'rest-client'
gem 'rinku'
gem 'sanitize'
gem 'sass'
gem 'sidekiq', '2.15.1'
gem 'sidekiq-failures'
gem 'sinatra', require: nil
gem 'slim'  # required for sidekiq-web

# URGENT fix needed see: https://github.com/cowboyd/therubyracer/pull/280
gem 'therubyracer-discourse', require: 'v8'
gem 'thin', require: false
gem 'highline', require: false
gem 'rack-protection' # security

# Gems used only for assets and not required
# in production environments by default.
# allow everywhere for now cause we are allowing asset debugging in prd
group :assets do
  gem 'sass-rails'
  gem 'uglifier'
end

group :test do
  gem 'fakeweb', '~> 1.3.0', require: false
  gem 'minitest', require: false
end

group :test, :development do
  gem 'mock_redis'
  gem 'listen', '0.7.3', require: false
  gem 'certified', require: false
  gem 'fabrication', require: false
  gem 'qunit-rails'
  gem 'mocha', require: false
  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false
  gem 'rspec-rails', require: false
  gem 'shoulda', require: false
  gem 'simplecov', require: false
  gem 'timecop'
  gem 'rspec-given'
  gem 'pry-rails'
  gem 'pry-nav'
  gem 'spork-rails'
end

group :development do
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'librarian', '>= 0.0.25', require: false
  gem 'annotate'
end

# Gem that enables support for plugins. It is required.
# TODO: does this really need to be a gem ?
gem 'discourse_plugin', path: 'vendor/gems/discourse_plugin'

# this is an optional gem, it provides a high performance replacement
# to String#blank? a method that is called quite frequently in current
# ActiveRecord, this may change in the future
gem 'fast_blank' #, github: "SamSaffron/fast_blank"

# this provides a very efficient lru cache
gem 'lru_redux'

# IMPORTANT: mini profiler monkey patches, so it better be required last
#  If you want to amend mini profiler to do the monkey patches in the railstie
#  we are open to it. by deferring require to the initializer we can configure disourse installs without it

gem 'flamegraph', require: false
gem 'rack-mini-profiler', require: false

# used for caching, optional
gem 'rack-cors', require: false
gem 'unicorn', require: false
gem 'puma', require: false
gem 'rbtrace', require: false, platform: :mri

# required for feed importing and embedding
gem 'ruby-readability', require: false
gem 'simple-rss', require: false

# perftools only works on 1.9 atm
group :profile do
  # travis refuses to install this, instead of fuffing, just avoid it for now
  #
  # if you need to profile, uncomment out this line
  # gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', platform: :mri_19
end
