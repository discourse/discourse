source 'https://rubygems.org'
# if there is a super emergency and rubygems is playing up, try
#source 'http://production.cf.rubygems.org'

module ::Kernel
  def rails_master?
    ENV["RAILS_MASTER"] == '1'
  end
end

if rails_master?
  # monkey patching to support dual booting
  module Bundler::SharedHelpers
    def default_lockfile=(path)
      @default_lockfile = path
    end
    def default_lockfile
      @default_lockfile ||= Pathname.new("#{default_gemfile}.lock")
    end
  end

  Bundler::SharedHelpers.default_lockfile = Pathname.new("#{Bundler::SharedHelpers.default_gemfile}_master.lock")

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

end

# Monkey patch bundler to support mri_21
unless Bundler::Dependency::PLATFORM_MAP.include? :mri_21
   STDERR.puts
   STDERR.puts "WARNING: --------------------------------------------------------------------------"
   STDERR.puts "You are running an old version of bundler, please update by running: gem install bundler"
   STDERR.puts
   map = Bundler::Dependency::PLATFORM_MAP.dup
   map[:mri_21] = Gem::Platform::RUBY
   map.freeze
   Bundler::Dependency.send(:remove_const, "PLATFORM_MAP")
   Bundler::Dependency.const_set("PLATFORM_MAP", map)

   Bundler::Dsl.send(:remove_const, "VALID_PLATFORMS")
   Bundler::Dsl.const_set("VALID_PLATFORMS", map.keys.freeze)
   class ::Bundler::CurrentRuby
      def on_21?
         RUBY_VERSION =~ /^2\.1/
      end
      def mri_21?
        mri? && on_21?
      end
   end
   class ::Bundler::Dependency
      private
      def on_21?
         RUBY_VERSION =~ /^2\.1/
      end
      def mri_21?
        mri? && on_21?
      end
   end
end


if rails_master?
  gem 'arel', git: 'https://github.com/rails/arel.git'
  gem 'rails', git: 'https://github.com/rails/rails.git'
  gem 'rails-observers', git: 'https://github.com/SamSaffron/rails-observers.git'
  gem 'seed-fu', git: 'https://github.com/SamSaffron/seed-fu.git', branch: 'discourse'
else
  gem 'seed-fu', '~> 2.3.3'
  gem 'rails'
  gem 'rails-observers'
end

gem 'actionpack-action_caching'

# Rails 4.1.6+ will relax the mail gem version requirement to `~> 2.5, >= 2.5.4`.
# However, mail gem 2.6.x currently does not work with discourse because of the
# reference to `Mail::RFC2822Parser` in `lib/email.rb`. This ensure discourse
# would continue to work with Rails 4.1.6+ when it is released.
gem 'mail', '~> 2.5.4'

#gem 'redis-rails'
gem 'hiredis'
gem 'redis', require:  ["redis", "redis/connection/hiredis"]

# We use some ams 0.8.0 features, need to amend code
# to support 0.9 etc, bench needs to run and ensure no
# perf regressions
if rails_master?
  gem 'active_model_serializers', github: 'rails-api/active_model_serializers', branch: '0-8-stable'
else
  gem 'active_model_serializers', '~> 0.8.0'
end


gem 'onebox'

gem 'ember-rails'
gem 'ember-source', '1.9.0.beta.4'
gem 'handlebars-source', '2.0.0'
gem 'barber'

gem 'message_bus'
gem 'rails_multisite', path: 'vendor/gems/rails_multisite'

gem 'redcarpet', require: false
gem 'eventmachine'
gem 'fast_xs'

gem 'fast_xor'
gem 'fastimage'
gem 'fog', '1.22.1', require: false
gem 'unf', require: false

gem 'email_reply_parser'

# note: for image_optim to correctly work you need
# sudo apt-get install -y advancecomp gifsicle jpegoptim libjpeg-progs optipng pngcrush
#
# Sam: held back, getting weird errors in latest
gem 'image_optim', '0.9.1'
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

if rails_master?
  # native casting
  gem 'pg', '0.18.0.pre20141117110243'
else
  # while resolving https://groups.google.com/forum/#!topic/ruby-pg/5_ylGmog1S4
  gem 'pg', '0.15.1'
end

gem 'pry-rails', require: false
gem 'rake'


gem 'rest-client'
gem 'rinku'
gem 'sanitize'
gem 'sass'
gem 'sidekiq'

# for sidekiq web
gem 'sinatra', require: nil

gem 'therubyracer'
gem 'thin', require: false
gem 'highline', require: false
gem 'rack-protection' # security

# Gems used only for assets and not required
# in production environments by default.
# allow everywhere for now cause we are allowing asset debugging in prd
group :assets do

  if rails_master?
    gem 'sass-rails', git: 'https://github.com/rails/sass-rails.git'
  else
    # later is breaking our asset compliation extensions
    gem 'sass-rails', '4.0.2'
  end

  gem 'uglifier'
  gem 'rtlit', require: false # for css rtling
end

group :test do
  gem 'fakeweb', '~> 1.3.0', require: false
  gem 'minitest', require: false
end

group :test, :development do
  # while upgrading to 3
  gem 'rspec', '2.99.0'
  gem 'mock_redis'
  gem 'listen', '0.7.3', require: false
  gem 'certified', require: false
  # later appears to break Fabricate(:topic, category: category)
  gem 'fabrication', '2.9.8', require: false
  gem 'qunit-rails'
  gem 'mocha', require: false
  gem 'rb-fsevent', require: RUBY_PLATFORM =~ /darwin/i ? 'rb-fsevent' : false
  gem 'rb-inotify', '~> 0.9', require: RUBY_PLATFORM =~ /linux/i ? 'rb-inotify' : false
  gem 'rspec-rails', require: false
  gem 'shoulda', require: false
  gem 'simplecov', require: false
  gem 'timecop'
  gem 'rspec-given'
  gem 'pry-nav'
  gem 'spork-rails'
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
#  If you want to amend mini profiler to do the monkey patches in the railstie
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
gem 'stackprof', require: false, platform: :mri_21
gem 'memory_profiler', require: false, platform: :mri_21

gem 'rmmseg-cpp', require: false

gem 'stringex', require: false

gem 'logster'

# perftools only works on 1.9 atm
group :profile do
  # travis refuses to install this, instead of fuffing, just avoid it for now
  #
  # if you need to profile, uncomment out this line
  # gem 'rack-perftools_profiler', require: 'rack/perftools_profiler', platform: :mri_19
end
