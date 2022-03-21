# frozen_string_literal: true

# note, we require 2.5.2 and up cause 2.5.1 had some mail bugs we no longer
# monkey patch, so this avoids people booting with this problem version
begin
  if Gem::Version.new(RUBY_VERSION) < Gem::Version.new("2.5.2")
    STDERR.puts "Discourse requires Ruby 2.5.2 or up"
    exit 1
  end
rescue
  # no String#match?
  STDERR.puts "Discourse requires Ruby 2.5.2 or up"
  exit 1
end

require File.expand_path('../boot', __FILE__)
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'sprockets/railtie'

# Plugin related stuff
require_relative '../lib/plugin'
require_relative '../lib/discourse_event'
require_relative '../lib/discourse_plugin_registry'

require_relative '../lib/plugin_gem'

# Global config
require_relative '../app/models/global_setting'
GlobalSetting.configure!
if GlobalSetting.load_plugins?
  # Support for plugins to register custom setting providers. They can do this
  # by having a file, `register_provider.rb` in their root that will be run
  # at this point.

  Dir.glob(File.join(File.dirname(__FILE__), '../plugins', '*', "register_provider.rb")) do |p|
    require p
  end
end
GlobalSetting.load_defaults
if GlobalSetting.try(:cdn_url).present? && GlobalSetting.cdn_url !~ /^https?:\/\//
  STDERR.puts "WARNING: Your CDN URL does not begin with a protocol like `https://` - this is probably not going to work"
end

if ENV['SKIP_DB_AND_REDIS'] == '1'
  GlobalSetting.skip_db = true
  GlobalSetting.skip_redis = true
end

if !GlobalSetting.skip_db?
  require 'rails_failover/active_record'
end

if !GlobalSetting.skip_redis?
  require 'rails_failover/redis'
end

require 'pry-rails' if Rails.env.development?

if defined?(Bundler)
  bundler_groups = [:default]

  if !Rails.env.production?
    bundler_groups = bundler_groups.concat(Rails.groups(
      assets: %w(development test profile)
    ))
  end

  Bundler.require(*bundler_groups)
end

require_relative '../lib/require_dependency_backward_compatibility'

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
    require 'js_locale_helper'

    # tiny file needed by site settings
    require 'highlight_js'

    # we skip it cause we configure it in the initializer
    # the railtie for message_bus would insert it in the
    # wrong position
    config.skip_message_bus_middleware = true
    config.skip_multisite_middleware = true
    config.skip_rails_failover_active_record_middleware = true

    multisite_config_path = ENV['DISCOURSE_MULTISITE_CONFIG_PATH'] || GlobalSetting.multisite_config_path
    config.multisite_config_path = File.absolute_path(multisite_config_path, Rails.root)

    # Disable so this is only run manually
    # we may want to change this later on
    # issue is image_optim crashes on missing dependencies
    config.assets.image_optim = false

    require 'discourse_inflector'
    Rails.autoloaders.each do |autoloader|
      autoloader.inflector = DiscourseInflector.new
      autoloader.inflector.inflect(
        'onceoff' => 'Jobs',
        'regular' => 'Jobs',
        'scheduled' => 'Jobs'
      )
    end

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths << "#{root}/lib"

    config.eager_load_paths << "#{root}/lib"

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Allows us to skip minification on some files
    config.assets.skip_minification = []

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # auto-load locales in plugins
    # NOTE: we load both client & server locales since some might be used by PrettyText
    config.i18n.load_path += Dir["#{Rails.root}/plugins/*/config/locales/*.yml"]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # see: http://stackoverflow.com/questions/11894180/how-does-one-correctly-add-custom-sql-dml-in-migrations/11894420#11894420
    config.active_record.schema_format = :sql

    # We use this in development-mode only (see development.rb)
    config.active_record.use_schema_cache_dump = false

    # per https://www.owasp.org/index.php/Password_Storage_Cheat_Sheet
    config.pbkdf2_iterations = 64000
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

    if !(Rails.env.development? || ENV['SKIP_ENFORCE_HOSTNAME'] == "1")
      require 'middleware/enforce_hostname'
      config.middleware.insert_after Rack::MethodOverride, Middleware::EnforceHostname
    end

    require 'content_security_policy/middleware'
    config.middleware.swap ActionDispatch::ContentSecurityPolicy::Middleware, ContentSecurityPolicy::Middleware

    require 'middleware/discourse_public_exceptions'
    config.exceptions_app = Middleware::DiscoursePublicExceptions.new(Rails.public_path)

    # Our templates shouldn't start with 'discourse/app/templates'
    config.handlebars.templates_root = {
      'discourse/app/templates' => '',
      'admin/addon/templates' => 'admin/templates/',
      'select-kit/addon/templates' => 'select-kit/templates/'
    }

    config.handlebars.raw_template_namespace = "__DISCOURSE_RAW_TEMPLATES"
    Sprockets.register_mime_type 'text/x-handlebars', extensions: ['.hbr']
    Sprockets.register_transformer 'text/x-handlebars', 'application/javascript', Ember::Handlebars::Template

    require 'discourse_js_processor'

    Sprockets.register_mime_type 'application/javascript', extensions: ['.js', '.es6', '.js.es6'], charset: :unicode
    Sprockets.register_postprocessor 'application/javascript', DiscourseJsProcessor

    require 'discourse_redis'
    require 'logster/redis_store'
    # Use redis for our cache
    config.cache_store = DiscourseRedis.new_redis_store
    Discourse.redis = DiscourseRedis.new
    Logster.store = Logster::RedisStore.new(DiscourseRedis.new)

    # Deprecated
    $redis = Discourse.redis # rubocop:disable Style/GlobalVars

    # we configure rack cache on demand in an initializer
    # our setup does not use rack cache and instead defers to nginx
    config.action_dispatch.rack_cache = nil

    # ember stuff only used for asset precompilation, production variant plays up
    config.ember.variant = :development
    config.ember.ember_location = "#{Rails.root}/vendor/assets/javascripts/production/ember.js"
    config.ember.handlebars_location = "#{Rails.root}/vendor/assets/javascripts/handlebars.js"

    require 'auth'

    if GlobalSetting.relative_url_root.present?
      config.relative_url_root = GlobalSetting.relative_url_root
    end

    if Rails.env.test? && GlobalSetting.load_plugins?
      Discourse.activate_plugins!
    elsif GlobalSetting.load_plugins?
      Plugin.initialization_guard do
        Discourse.activate_plugins!
      end
    end

    # Use discourse-fonts gem to symlink fonts and generate .scss file
    fonts_path = File.join(config.root, 'public/fonts')
    Discourse::Utils.atomic_ln_s(DiscourseFonts.path_for_fonts, fonts_path)

    require 'stylesheet/manager'
    require 'svg_sprite'

    config.after_initialize do
      # Load plugins
      Plugin.initialization_guard do
        Discourse.plugins.each(&:notify_after_initialize)
      end

      # we got to clear the pool in case plugins connect
      ActiveRecord::Base.connection_handler.clear_active_connections!

      # This nasty hack is required for not precompiling QUnit assets
      # in test mode. see: https://github.com/rails/sprockets-rails/issues/299#issuecomment-167701012
      ActiveSupport.on_load(:action_view) do
        default_checker = ActionView::Base.precompiled_asset_checker

        ActionView::Base.precompiled_asset_checker = -> logical_path do
          default_checker[logical_path] ||
            %w{qunit.js
              qunit.css
              test_helper.css
              discourse/tests/test-boot-rails.js
              wizard/test/test_helper.js
            }.include?(logical_path) ||
            logical_path =~ /\/node_modules/ ||
            logical_path =~ /\/dist/
        end
      end
    end

    if ENV['RBTRACE'] == "1"
      require 'rbtrace'
    end

    config.generators do |g|
      g.test_framework :rspec, fixture: false
    end
  end
end
