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
require_relative '../lib/plugin_initialization_guard'
require_relative '../lib/discourse_event'
require_relative '../lib/discourse_plugin_registry'

require_relative '../lib/plugin_gem'

# Global config
require_relative '../app/models/global_setting'
GlobalSetting.configure!
if GlobalSetting.load_plugins?
  require_relative '../lib/custom_setting_providers'
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

require 'discourse_fonts'

require_relative '../lib/zeitwerk_config.rb'

if defined?(Bundler)
  bundler_groups = [:default]

  if !Rails.env.production?
    bundler_groups = bundler_groups.concat(Rails.groups(
      assets: %w(development test profile)
    ))
  end

  Bundler.require(*bundler_groups)
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

    # this pattern is somewhat odd but the reloader gets very
    # confused here if we load the deps without `lib` it thinks
    # discourse.rb is under the discourse folder incorrectly
    require_dependency 'lib/discourse'
    require_dependency 'lib/js_locale_helper'

    # tiny file needed by site settings
    require_dependency 'lib/highlight_js/highlight_js'

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

    config.autoloader = :zeitwerk

    # Custom directories with classes and modules you want to be autoloadable.
    config.autoload_paths += Dir["#{config.root}/app"]
    config.autoload_paths += Dir["#{config.root}/app/jobs"]
    config.autoload_paths += Dir["#{config.root}/app/serializers"]
    config.autoload_paths += Dir["#{config.root}/lib"]
    config.autoload_paths += Dir["#{config.root}/lib/common_passwords"]
    config.autoload_paths += Dir["#{config.root}/lib/highlight_js"]
    config.autoload_paths += Dir["#{config.root}/lib/i18n"]
    config.autoload_paths += Dir["#{config.root}/lib/validators/"]

    Rails.autoloaders.main.ignore(Dir["#{config.root}/app/models/reports"])
    Rails.autoloaders.main.ignore(Dir["#{config.root}/lib/freedom_patches"])

    def watchable_args
      files, dirs = super

      # Skip the assets directory. It doesn't contain any .rb files, so watching it
      # is just slowing things down and raising warnings about node_modules symlinks
      app_file_extensions = dirs.delete("#{config.root}/app")
      Dir["#{config.root}/app/*"].reject { |path| path.end_with? "/assets" }.each do |path|
        dirs[path] = app_file_extensions
      end

      [files, dirs]
    end

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    config.assets.paths += %W(#{config.root}/config/locales #{config.root}/public/javascripts)

    # Allows us to skip minification on some files
    config.assets.skip_minification = []

    # explicitly precompile any images in plugins ( /assets/images ) path
    config.assets.precompile += [lambda do |filename, path|
      path =~ /assets\/images/ && !%w(.js .css).include?(File.extname(filename))
    end]

    config.assets.precompile += %w{
      vendor.js
      admin.js
      browser-detect.js
      browser-update.js
      break_string.js
      ember_jquery.js
      pretty-text-bundle.js
      wizard-application.js
      wizard-vendor.js
      markdown-it-bundle.js
      service-worker.js
      google-tag-manager.js
      google-universal-analytics-v3.js
      google-universal-analytics-v4.js
      start-discourse.js
      print-page.js
      omniauth-complete.js
      activate-account.js
      auto-redirect.js
      wizard-start.js
      locales/i18n.js
      discourse/app/lib/webauthn.js
      confirm-new-email/confirm-new-email.js
      confirm-new-email/bootstrap.js
      onpopstate-handler.js
      embed-application.js
      discourse/tests/active-plugins.js
      discourse/tests/test_starter.js
    }

    if ENV['EMBER_CLI_PROD_ASSETS'] == "0"
      config.assets.precompile += %w{
        discourse/tests/test-support-rails.js
        discourse/tests/test-helpers-rails.js
        vendor-theme-tests.js
      }
    end

    # Precompile all available locales
    unless GlobalSetting.try(:omit_base_locales)
      Dir.glob("#{config.root}/app/assets/javascripts/locales/*.js.erb").each do |file|
        config.assets.precompile << "locales/#{file.match(/([a-z_A-Z]+\.js)\.erb$/)[1]}"
      end
    end

    # out of the box sprockets 3 grabs loose files that are hanging in assets,
    # the exclusion list does not include hbs so you double compile all this stuff
    initializer :fix_sprockets_loose_file_searcher, after: :set_default_precompile do |app|
      app.config.assets.precompile.delete(Sprockets::Railtie::LOOSE_APP_ASSETS)

      # We don't want application from node_modules, only from the root
      app.config.assets.precompile.delete(/(?:\/|\\|\A)application\.(css|js)$/)
      app.config.assets.precompile += ['application.js']

      start_path = ::Rails.root.join("app/assets").to_s
      exclude = ['.es6', '.hbs', '.hbr', '.js', '.css', '.lock', '.json', '.log', '.html', '']
      app.config.assets.precompile << lambda do |logical_path, filename|
        filename.start_with?(start_path) &&
        !filename.include?("/node_modules/") &&
        !filename.include?("/dist/") &&
        !exclude.include?(File.extname(logical_path))
      end
    end

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    # auto-load locales in plugins
    # NOTE: we load both client & server locales since some might be used by PrettyText
    config.i18n.load_path += Dir["#{Rails.root}/plugins/*/config/locales/*.yml"]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = 'utf-8'

    # Configure sensitive parameters which will be filtered from the log file.
    config.filter_parameters += [
      :password,
      :pop3_polling_password,
      :api_key,
      :s3_secret_access_key,
      :twitter_consumer_secret,
      :facebook_app_secret,
      :github_client_secret,
      :second_factor_token,
    ]

    # Enable the asset pipeline
    config.assets.enabled = true

    # Version of your assets, change this if you want to expire all your assets
    config.assets.version = '1.2.4'

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
      plugin_initialization_guard do
        Discourse.activate_plugins!
      end
    end

    Discourse.find_plugin_js_assets(include_disabled: true).each do |file|
      config.assets.precompile << "#{file}.js"
    end

    # Use discourse-fonts gem to symlink fonts and generate .scss file
    fonts_path = File.join(config.root, 'public/fonts')
    Discourse::Utils.atomic_ln_s(DiscourseFonts.path_for_fonts, fonts_path)

    require_dependency 'stylesheet/manager'
    require_dependency 'svg_sprite/svg_sprite'

    config.after_initialize do
      # require common dependencies that are often required by plugins
      # in the past observers would load them as side-effects
      # correct behavior is for plugins to require stuff they need,
      # however it would be a risky and breaking change not to require here
      require_dependency 'category'
      require_dependency 'post'
      require_dependency 'topic'
      require_dependency 'user'
      require_dependency 'post_action'
      require_dependency 'post_revision'
      require_dependency 'notification'
      require_dependency 'topic_user'
      require_dependency 'topic_view'
      require_dependency 'topic_list'
      require_dependency 'group'
      require_dependency 'user_field'
      require_dependency 'post_action_type'
      # Ensure that Discourse event triggers for web hooks are loaded
      require_dependency 'web_hook'

      # Load plugins
      plugin_initialization_guard do
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
