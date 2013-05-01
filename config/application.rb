require File.expand_path('../boot', __FILE__)
require 'rails/all'
require 'redis-store' # HACK

# Plugin related stuff
require_relative '../lib/discourse_plugin_registry'

if defined?(Bundler)
  # If you precompile assets before deploying to production, use this line
  Bundler.require(*Rails.groups(assets: %w(development test profile)))
  # If you want your assets lazily compiled in production, use this line
  # Bundler.require(:default, :assets, Rails.env)
end

module Discourse
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    require 'discourse'

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += %W(#{config.root}/app/serializers)

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.assets.paths += %W(#{config.root}/config/locales)

    config.assets.precompile += ['admin.js', 'admin.css', 'shiny/shiny.css', 'preload_store.js', 'jquery.js']

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
        :message_bus_observer,
        :post_alert_observer,
        :search_observer
    ]

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'Eastern Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [:password]

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

    # dumping rack lock cause the message bus does not work with it (throw :async, it catches Exception)
    # see: https://github.com/sporkrb/spork/issues/66
    # rake assets:precompile also fails
    config.threadsafe! unless $PROGRAM_NAME =~ /spork|rake/

    # route all exceptions via our router
    config.exceptions_app = self.routes

    # Our templates shouldn't start with 'discourse/templates'
    config.handlebars.templates_root = 'discourse/templates'

    require 'discourse_redis'
    # Use redis for our cache
    config.cache_store = DiscourseRedis.new_redis_store

    # we configure rack cache on demand in an initializer
    # our setup does not use rack cache and instead defers to nginx
    config.action_dispatch.rack_cache =  nil

    # ember stuff only used for asset precompliation, production variant plays up
    config.ember.variant = :development
    config.ember.ember_location = "#{Rails.root}/app/assets/javascripts/external_production/ember.js"
    config.ember.handlebars_location = "#{Rails.root}/app/assets/javascripts/external/handlebars-1.0.rc.3.js"

    # So open id logs somewhere sane
    config.after_initialize do
      OpenID::Util.logger = Rails.logger
    end
  end
end
