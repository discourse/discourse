# frozen_string_literal: true

if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("3.2.0")
  STDERR.puts "Discourse requires Ruby 3.2 or above"
  exit 1
end

require File.expand_path("../boot", __FILE__)
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_mailer/railtie"
require "sprockets/railtie"

if !Rails.env.production?
  recommended = File.read(".ruby-version.sample").strip
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new(recommended)
    STDERR.puts "[Warning] Discourse recommends developing using Ruby v#{recommended} or above. You are using v#{RUBY_VERSION}."
  end
end

# Plugin related stuff
require_relative "../lib/plugin"
require_relative "../lib/discourse_event"
require_relative "../lib/discourse_plugin_registry"

require_relative "../lib/plugin_gem"

# Global config
require_relative "../app/models/global_setting"
GlobalSetting.configure!
if GlobalSetting.load_plugins?
  # Support for plugins to register custom setting providers. They can do this
  # by having a file, `register_provider.rb` in their root that will be run
  # at this point.

  Dir.glob(File.join(File.dirname(__FILE__), "../plugins", "*", "register_provider.rb")) do |p|
    require p
  end
end
GlobalSetting.load_defaults
if GlobalSetting.try(:cdn_url).present? && GlobalSetting.cdn_url !~ %r{^https?://}
  STDERR.puts "WARNING: Your CDN URL does not begin with a protocol like `https://` - this is probably not going to work"
end

if ENV["SKIP_DB_AND_REDIS"] == "1"
  GlobalSetting.skip_db = true
  GlobalSetting.skip_redis = true
end

require "rails_failover/active_record" if !GlobalSetting.skip_db?

require "rails_failover/redis" if !GlobalSetting.skip_redis?

require "pry-rails" if Rails.env.development?
require "pry-byebug" if Rails.env.development?

require "discourse_fonts"

require_relative "../lib/ember_cli"

if defined?(Bundler)
  bundler_groups = [:default]

  if !Rails.env.production?
    bundler_groups = bundler_groups.concat(Rails.groups(assets: %w[development test profile]))
  end

  Bundler.require(*bundler_groups)
end

require_relative "../lib/require_dependency_backward_compatibility"

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

    require "discourse"
    require "js_locale_helper"

    # tiny file needed by site settings
    require "highlight_js"

    config.load_defaults 7.2
    config.yjit = GlobalSetting.yjit_enabled
    config.active_record.cache_versioning = false # our custom cache class doesn’t support this
    config.action_controller.forgery_protection_origin_check = false
    config.active_record.belongs_to_required_by_default = false
    config.active_record.yaml_column_permitted_classes = [
      Hash,
      HashWithIndifferentAccess,
      Time,
      Symbol,
    ]
    config.active_support.key_generator_hash_digest_class = OpenSSL::Digest::SHA1
    config.action_dispatch.cookies_serializer = :hybrid
    config.action_controller.wrap_parameters_by_default = false
    config.active_support.cache_format_version = 7.1

    # we skip it cause we configure it in the initializer
    # the railtie for message_bus would insert it in the
    # wrong position
    config.skip_message_bus_middleware = true
    config.skip_multisite_middleware = true
    config.skip_rails_failover_active_record_middleware = true

    multisite_config_path =
      ENV["DISCOURSE_MULTISITE_CONFIG_PATH"] || GlobalSetting.multisite_config_path
    config.multisite_config_path = File.absolute_path(multisite_config_path, Rails.root)

    config.autoload_lib(ignore: %w[common_passwords emoji generators javascripts tasks])
    Rails.autoloaders.main.do_not_eager_load(config.root.join("lib"))
    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths << "#{root}/lib/guardian"
    config.autoload_paths << "#{root}/lib/i18n"
    config.autoload_paths << "#{root}/lib/validators"

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Allows us to skip minification on some files
    config.assets.skip_minification = []

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = "UTC"

    # auto-load locales in plugins
    # NOTE: we load both client & server locales since some might be used by PrettyText
    config.i18n.load_path += Dir["#{Rails.root}/plugins/*/config/locales/*.yml"]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    # see: http://stackoverflow.com/questions/11894180/how-does-one-correctly-add-custom-sql-dml-in-migrations/11894420#11894420
    config.active_record.schema_format = :sql

    # We use this in development-mode only (see development.rb)
    config.active_record.use_schema_cache_dump = false

    # per https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
    config.pbkdf2_iterations = 600_000
    config.pbkdf2_algorithm = "sha256"

    # rack lock is nothing but trouble, get rid of it
    # for some reason still seeing it in Rails 4
    config.middleware.delete Rack::Lock

    # wrong place in middleware stack AND request tracker handles it
    config.middleware.delete Rack::Runtime

    # ETags are pointless, we are dynamically compressing
    # so nginx strips etags, may revisit when mainline nginx
    # supports etags (post 1.7)
    config.middleware.delete Rack::ETag

    if !(Rails.env.development? || ENV["SKIP_ENFORCE_HOSTNAME"] == "1")
      require "middleware/enforce_hostname"
      config.middleware.insert_after Rack::MethodOverride, Middleware::EnforceHostname
    end

    require "content_security_policy/middleware"
    config.middleware.swap ActionDispatch::ContentSecurityPolicy::Middleware,
                           ContentSecurityPolicy::Middleware

    require "middleware/csp_script_nonce_injector"
    config.middleware.insert_after(ActionDispatch::Flash, Middleware::CspScriptNonceInjector)

    require "middleware/discourse_public_exceptions"
    config.exceptions_app = Middleware::DiscoursePublicExceptions.new(Rails.public_path)

    require "discourse_js_processor"
    require "discourse_sourcemapping_url_processor"

    Sprockets.register_mime_type "application/javascript",
                                 extensions: %w[.js .es6 .js.es6],
                                 charset: :unicode
    Sprockets.register_postprocessor "application/javascript", DiscourseJsProcessor

    class SprocketsSassUnsupported
      def self.call(*args)
        raise "Discourse does not support compiling scss/sass files via Sprockets"
      end
    end

    Sprockets.register_engine(".sass", SprocketsSassUnsupported, silence_deprecation: true)
    Sprockets.register_engine(".scss", SprocketsSassUnsupported, silence_deprecation: true)

    Discourse::Application.initializer :prepend_ember_assets do |app|
      # Needs to be in its own initializer so it runs after the append_assets_path initializer defined by Sprockets
      app
        .config
        .assets
        .paths.unshift "#{app.config.root}/app/assets/javascripts/discourse/dist/assets"
      Sprockets.unregister_postprocessor "application/javascript",
                                         Sprockets::Rails::SourcemappingUrlProcessor
      Sprockets.register_postprocessor "application/javascript", DiscourseSourcemappingUrlProcessor
    end

    require "discourse_redis"
    require "logster/redis_store"
    # Use redis for our cache
    config.cache_store = DiscourseRedis.new_redis_store
    Discourse.redis = DiscourseRedis.new
    Logster.store = Logster::RedisStore.new(DiscourseRedis.new)

    # Deprecated
    $redis = Discourse.redis # rubocop:disable Style/GlobalVars

    # we configure rack cache on demand in an initializer
    # our setup does not use rack cache and instead defers to nginx
    config.action_dispatch.rack_cache = nil

    require "auth"

    if GlobalSetting.relative_url_root.present?
      config.relative_url_root = GlobalSetting.relative_url_root
    end

    if Rails.env.test? && GlobalSetting.load_plugins?
      Discourse.activate_plugins!
    elsif GlobalSetting.load_plugins?
      Plugin.initialization_guard { Discourse.activate_plugins! }
    end

    # Use discourse-fonts gem to symlink fonts and generate .scss file
    fonts_path = File.join(config.root, "public/fonts")
    if !File.exist?(fonts_path) || File.realpath(fonts_path) != DiscourseFonts.path_for_fonts
      STDERR.puts "Symlinking fonts from discourse-fonts gem"
      File.delete(fonts_path) if File.exist?(fonts_path)
      Discourse::Utils.atomic_ln_s(DiscourseFonts.path_for_fonts, fonts_path)
    end

    require "stylesheet/manager"
    require "svg_sprite"

    config.after_initialize do
      # Load plugins
      Plugin.initialization_guard { Discourse.plugins.each(&:notify_after_initialize) }

      # we got to clear the pool in case plugins connect
      ActiveRecord::Base.connection_handler.clear_active_connections!

      # Mailers and controllers may have been patched by plugins and when the
      # application is eager loaded, the list of public methods is cached.
      # We need to invalidate the existing caches, otherwise the new actions
      # won’t be seen by Rails.
      if Rails.configuration.eager_load
        AbstractController::Base.descendants.each do |controller|
          controller.clear_action_methods!
          controller.action_methods
        end
      end
    end

    require "rbtrace" if ENV["RBTRACE"] == "1"

    config.active_record.query_log_tags_enabled = true if ENV["RAILS_QUERY_LOG_TAGS"] == "1"

    config.generators { |g| g.test_framework :rspec, fixture: false }
  end
end
