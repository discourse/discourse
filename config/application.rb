require File.expand_path('../boot', __FILE__)
require 'rails/all'

# Plugin related stuff
require_relative '../lib/discourse_event'
require_relative '../lib/discourse_plugin'
require_relative '../lib/discourse_plugin_registry'

# Global config
require_relative '../app/models/global_setting'

require 'pry-rails' if Rails.env.development?

if defined?(Bundler)
  Bundler.require(*Rails.groups(assets: %w(development test profile)))
end

module Discourse
  class Application < Rails::Application
    def config.database_configuration
      if Rails.env.production?
        GlobalSetting.database_config
      else
        super
      end
    end
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    require 'discourse'
    require 'es6_module_transpiler/rails'
    require 'js_locale_helper'

    # mocha hates us, active_support/testing/mochaing.rb line 2 is requiring the wrong
    #  require, patched in source, on upgrade remove this
    if Rails.env.test? || Rails.env.development?
      require "mocha/version"
      require "mocha/deprecation"
      if Mocha::VERSION == "0.13.3" && Rails::VERSION::STRING == "3.2.12"
        Mocha::Deprecation.mode = :disabled
      end
    end

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += Dir["#{config.root}/app/serializers"]
    config.autoload_paths += Dir["#{config.root}/lib/validators/"]
    config.autoload_paths += Dir["#{config.root}/app"]

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.assets.paths += %W(#{config.root}/config/locales #{config.root}/public/javascripts)

    # explicitly precompile any images in plugins ( /assets/images ) path
    config.assets.precompile += [lambda do |filename, path|
      path =~ /assets\/images/ && !%w(.js .css).include?(File.extname(filename))
    end]

    config.assets.precompile += ['vendor.js', 'common.css', 'desktop.css', 'mobile.css', 'admin.js', 'admin.css', 'shiny/shiny.css', 'preload_store.js', 'browser-update.js', 'embed.css', 'break_string.js']

    # Precompile all defer
    Dir.glob("#{config.root}/app/assets/javascripts/defer/*.js").each do |file|
      config.assets.precompile << "defer/#{File.basename(file)}"
    end

    # Precompile all available locales
    Dir.glob("#{config.root}/app/assets/javascripts/locales/*.js.erb").each do |file|
      config.assets.precompile << "locales/#{file.match(/([a-z_A-Z]+\.js)\.erb$/)[1]}"
    end

    # Activate observers that should always be running.
    config.active_record.observers = [
        :user_email_observer,
        :user_action_observer,
        :post_alert_observer,
        :search_observer
    ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # auto-load server locale in plugins
    config.i18n.load_path += Dir["#{Rails.root}/plugins/*/config/locales/server.*.yml"]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [
        :password,
        :pop3_polling_password,
        :s3_secret_access_key,
        :twitter_consumer_secret,
        :facebook_app_secret,
        :github_client_secret
    ]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.2.4'

    # We need to be able to spin threads
    config.active_record.thread_safe!

    # see: http://stackoverflow.com/questions/11894180/how-does-one-correctly-add-custom-sql-dml-in-migrations/11894420#11894420
    config.active_record.schema_format = :sql

    # per https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
    config.pbkdf2_iterations = 64000
    config.pbkdf2_algorithm = "sha256"

    # rack lock is nothing but trouble, get rid of it
    # for some reason still seeing it in Rails 4
    config.middleware.delete Rack::Lock

    # ETags are pointless, we are dynamically compressing
    # so nginx strips etags, may revisit when mainline nginx
    # supports etags (post 1.7)
    config.middleware.delete Rack::ETag

    # route all exceptions via our router
    config.exceptions_app = self.routes

    # Our templates shouldn't start with 'discourse/templates'
    config.handlebars.templates_root = 'discourse/templates'

    require 'discourse_redis'
    require 'logster/redis_store'
    # Use redis for our cache
    config.cache_store = DiscourseRedis.new_redis_store
    $redis = DiscourseRedis.new
    Logster.store = Logster::RedisStore.new(DiscourseRedis.new)

    # we configure rack cache on demand in an initializer
    # our setup does not use rack cache and instead defers to nginx
    config.action_dispatch.rack_cache =  nil

    # ember stuff only used for asset precompliation, production variant plays up
    config.ember.variant = :development
    config.ember.ember_location = "#{Rails.root}/vendor/assets/javascripts/production/ember.js"
    config.ember.handlebars_location = "#{Rails.root}/vendor/assets/javascripts/handlebars.js"

    require 'auth'
    Discourse.activate_plugins! unless Rails.env.test? and ENV['LOAD_PLUGINS'] != "1"

    config.after_initialize do
      # So open id logs somewhere sane
      OpenID::Util.logger = Rails.logger
      if plugins = Discourse.plugins
        plugins.each{|plugin| plugin.notify_after_initialize}
      end
    end

    if ENV['RBTRACE'] == "1"
      require 'rbtrace'
    end

  end
end
