# frozen_string_literal: true
# rubocop:disable Style/GlobalVars

require 'cache'
require 'open3'
require_dependency 'route_format'
require_dependency 'plugin/instance'
require_dependency 'auth/default_current_user_provider'
require_dependency 'version'
require 'digest/sha1'

# Prevents errors with reloading dev with conditional includes
if Rails.env.development?
  require_dependency 'file_store/s3_store'
  require_dependency 'file_store/local_store'
end

module Discourse
  DB_POST_MIGRATE_PATH ||= "db/post_migrate"

  require 'sidekiq/exception_handler'
  class SidekiqExceptionHandler
    extend Sidekiq::ExceptionHandler
  end

  class Utils
    # Usage:
    #   Discourse::Utils.execute_command("pwd", chdir: 'mydirectory')
    # or with a block
    #   Discourse::Utils.execute_command(chdir: 'mydirectory') do |runner|
    #     runner.exec("pwd")
    #   end
    def self.execute_command(*command, **args)
      runner = CommandRunner.new(**args)

      if block_given?
        raise RuntimeError.new("Cannot pass command and block to execute_command") if command.present?
        yield runner
      else
        runner.exec(*command)
      end
    end

    def self.pretty_logs(logs)
      logs.join("\n".freeze)
    end

    private

    class CommandRunner
      def initialize(**init_params)
        @init_params = init_params
      end

      def exec(*command, **exec_params)
        raise RuntimeError.new("Cannot specify same parameters at block and command level") if (@init_params.keys & exec_params.keys).present?
        execute_command(*command, **@init_params.merge(exec_params))
      end

      private

      def execute_command(*command, failure_message: "", success_status_codes: [0], chdir: ".")
        stdout, stderr, status = Open3.capture3(*command, chdir: chdir)

        if !status.exited? || !success_status_codes.include?(status.exitstatus)
          failure_message = "#{failure_message}\n" if !failure_message.blank?
          raise "#{caller[0]}: #{failure_message}#{stderr}"
        end

        stdout
      end
    end
  end

  # Log an exception.
  #
  # If your code is in a scheduled job, it is recommended to use the
  # error_context() method in Jobs::Base to pass the job arguments and any
  # other desired context.
  # See app/jobs/base.rb for the error_context function.
  def self.handle_job_exception(ex, context = {}, parent_logger = nil)
    return if ex.class == Jobs::HandledExceptionWrapper

    context ||= {}
    parent_logger ||= SidekiqExceptionHandler

    cm = RailsMultisite::ConnectionManagement
    parent_logger.handle_exception(ex, {
      current_db: cm.current_db,
      current_hostname: cm.current_hostname
    }.merge(context))

    raise ex if Rails.env.test?
  end

  # Expected less matches than what we got in a find
  class TooManyMatches < StandardError; end

  # When they try to do something they should be logged in for
  class NotLoggedIn < StandardError; end

  # When the input is somehow bad
  class InvalidParameters < StandardError; end

  # When they don't have permission to do something
  class InvalidAccess < StandardError
    attr_reader :obj
    attr_reader :opts
    attr_reader :custom_message
    attr_reader :group

    def initialize(msg = nil, obj = nil, opts = nil)
      super(msg)

      @opts = opts || {}
      @obj = obj
      @custom_message = opts[:custom_message] if @opts[:custom_message]
      @group = opts[:group] if @opts[:group]
    end
  end

  # When something they want is not found
  class NotFound < StandardError
    attr_reader :status
    attr_reader :check_permalinks
    attr_reader :original_path
    attr_reader :custom_message

    def initialize(msg = nil, status: 404, check_permalinks: false, original_path: nil, custom_message: nil)
      super(msg)

      @status = status
      @check_permalinks = check_permalinks
      @original_path = original_path
      @custom_message = custom_message
    end
  end

  # When a setting is missing
  class SiteSettingMissing < StandardError; end

  # When ImageMagick is missing
  class ImageMagickMissing < StandardError; end

  # When read-only mode is enabled
  class ReadOnly < StandardError; end

  # Cross site request forgery
  class CSRF < StandardError; end

  class Deprecation < StandardError; end

  class ScssError < StandardError; end

  def self.filters
    @filters ||= [:latest, :unread, :new, :read, :posted, :bookmarks]
  end

  def self.anonymous_filters
    @anonymous_filters ||= [:latest, :top, :categories]
  end

  def self.top_menu_items
    @top_menu_items ||= Discourse.filters + [:categories, :top]
  end

  def self.anonymous_top_menu_items
    @anonymous_top_menu_items ||= Discourse.anonymous_filters + [:categories, :top]
  end

  PIXEL_RATIOS ||= [1, 1.5, 2, 3]

  def self.avatar_sizes
    # TODO: should cache these when we get a notification system for site settings
    set = Set.new

    SiteSetting.avatar_sizes.split("|").map(&:to_i).each do |size|
      PIXEL_RATIOS.each do |pixel_ratio|
        set << (size * pixel_ratio).to_i
      end
    end

    set
  end

  def self.activate_plugins!
    @plugins = []
    Plugin::Instance.find_all("#{Rails.root}/plugins").each do |p|
      v = p.metadata.required_version || Discourse::VERSION::STRING
      if Discourse.has_needed_version?(Discourse::VERSION::STRING, v)
        p.activate!
        @plugins << p
      else
        STDERR.puts "Could not activate #{p.metadata.name}, discourse does not meet required version (#{v})"
      end
    end
    DiscourseEvent.trigger(:after_plugin_activation)
  end

  def self.disabled_plugin_names
    plugins.select { |p| !p.enabled? }.map(&:name)
  end

  def self.plugins
    @plugins ||= []
  end

  def self.hidden_plugins
    @hidden_plugins ||= []
  end

  def self.visible_plugins
    self.plugins - self.hidden_plugins
  end

  def self.plugin_themes
    @plugin_themes ||= plugins.map(&:themes).flatten
  end

  def self.official_plugins
    plugins.find_all { |p| p.metadata.official? }
  end

  def self.unofficial_plugins
    plugins.find_all { |p| !p.metadata.official? }
  end

  def self.find_plugins(args)
    plugins.select do |plugin|
      next if args[:include_official] == false && plugin.metadata.official?
      next if args[:include_unofficial] == false && !plugin.metadata.official?
      next if !args[:include_disabled] && !plugin.enabled?

      true
    end
  end

  def self.find_plugin_css_assets(args)
    plugins = self.find_plugins(args)

    assets = []

    targets = [nil]
    targets << :mobile if args[:mobile_view]
    targets << :desktop if args[:desktop_view]

    targets.each do |target|
      assets += plugins.find_all do |plugin|
        plugin.css_asset_exists?(target)
      end.map do |plugin|
        target.nil? ? plugin.directory_name : "#{plugin.directory_name}_#{target}"
      end
    end

    assets
  end

  def self.find_plugin_js_assets(args)
    self.find_plugins(args).find_all do |plugin|
      plugin.js_asset_exists?
    end.map { |plugin| "plugins/#{plugin.directory_name}" }
  end

  def self.assets_digest
    @assets_digest ||= begin
      digest = Digest::MD5.hexdigest(ActionView::Base.assets_manifest.assets.values.sort.join)

      channel = "/global/asset-version"
      message = MessageBus.last_message(channel)

      unless message && message.data == digest
        MessageBus.publish channel, digest
      end
      digest
    end
  end

  BUILTIN_AUTH ||= [
    Auth::AuthProvider.new(authenticator: Auth::FacebookAuthenticator.new, frame_width: 580, frame_height: 400, icon: "fab-facebook"),
    Auth::AuthProvider.new(authenticator: Auth::GoogleOAuth2Authenticator.new, frame_width: 850, frame_height: 500), # Custom icon implemented in client
    Auth::AuthProvider.new(authenticator: Auth::GithubAuthenticator.new, icon: "fab-github"),
    Auth::AuthProvider.new(authenticator: Auth::TwitterAuthenticator.new, icon: "fab-twitter"),
    Auth::AuthProvider.new(authenticator: Auth::InstagramAuthenticator.new, icon: "fab-instagram"),
    Auth::AuthProvider.new(authenticator: Auth::DiscordAuthenticator.new, icon: "fab-discord")
  ]

  def self.auth_providers
    BUILTIN_AUTH + DiscoursePluginRegistry.auth_providers.to_a
  end

  def self.enabled_auth_providers
    auth_providers.select { |provider|  provider.authenticator.enabled?  }
  end

  def self.authenticators
    # NOTE: this bypasses the site settings and gives a list of everything, we need to register every middleware
    #  for the cases of multisite
    auth_providers.map(&:authenticator)
  end

  def self.enabled_authenticators
    authenticators.select { |authenticator|  authenticator.enabled?  }
  end

  def self.cache
    @cache ||= begin
      if GlobalSetting.skip_redis?
        ActiveSupport::Cache::MemoryStore.new
      else
        Cache.new
      end
    end
  end

  # Get the current base URL for the current site
  def self.current_hostname
    SiteSetting.force_hostname.presence || RailsMultisite::ConnectionManagement.current_hostname
  end

  def self.base_uri(default_value = "")
    ActionController::Base.config.relative_url_root.presence || default_value
  end

  def self.base_protocol
    SiteSetting.force_https? ? "https" : "http"
  end

  def self.base_url_no_prefix
    default_port = SiteSetting.force_https? ? 443 : 80
    url = +"#{base_protocol}://#{current_hostname}"
    url << ":#{SiteSetting.port}" if SiteSetting.port.to_i > 0 && SiteSetting.port.to_i != default_port

    if Rails.env.development? && SiteSetting.port.blank?
      url << ":#{ENV["UNICORN_PORT"] || 3000}"
    end

    url
  end

  def self.base_url
    base_url_no_prefix + base_uri
  end

  def self.route_for(uri)
    unless uri.is_a?(URI)
      uri = begin
        URI(uri)
      rescue URI::Error
      end
    end

    return unless uri

    path = +(uri.path || "")
    if !uri.host || (uri.host == Discourse.current_hostname && path.start_with?(Discourse.base_uri))
      path.slice!(Discourse.base_uri)
      return Rails.application.routes.recognize_path(path)
    end

    nil
  rescue ActionController::RoutingError
    nil
  end

  class << self
    alias_method :base_path, :base_uri
    alias_method :base_url_no_path, :base_url_no_prefix
  end

  READONLY_MODE_KEY_TTL  ||= 60
  READONLY_MODE_KEY      ||= 'readonly_mode'
  PG_READONLY_MODE_KEY   ||= 'readonly_mode:postgres'
  USER_READONLY_MODE_KEY ||= 'readonly_mode:user'

  READONLY_KEYS ||= [
    READONLY_MODE_KEY,
    PG_READONLY_MODE_KEY,
    USER_READONLY_MODE_KEY
  ]

  def self.enable_readonly_mode(key = READONLY_MODE_KEY)
    if key == USER_READONLY_MODE_KEY
      Discourse.redis.set(key, 1)
    else
      Discourse.redis.setex(key, READONLY_MODE_KEY_TTL, 1)
      keep_readonly_mode(key) if !Rails.env.test?
    end

    MessageBus.publish(readonly_channel, true)
    Site.clear_anon_cache!
    true
  end

  def self.keep_readonly_mode(key)
    # extend the expiry by 1 minute every 30 seconds
    @mutex ||= Mutex.new

    @mutex.synchronize do
      @dbs ||= Set.new
      @dbs << RailsMultisite::ConnectionManagement.current_db
      @threads ||= {}

      unless @threads[key]&.alive?
        @threads[key] = Thread.new do
          while @dbs.size > 0 do
            sleep 30

            @mutex.synchronize do
              @dbs.each do |db|
                RailsMultisite::ConnectionManagement.with_connection(db) do
                  if !Discourse.redis.expire(key, READONLY_MODE_KEY_TTL)
                    @dbs.delete(db)
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  def self.disable_readonly_mode(key = READONLY_MODE_KEY)
    Discourse.redis.del(key)
    MessageBus.publish(readonly_channel, false)
    Site.clear_anon_cache!
    true
  end

  def self.readonly_mode?(keys = READONLY_KEYS)
    recently_readonly? || Discourse.redis.mget(*keys).compact.present?
  end

  def self.pg_readonly_mode?
    Discourse.redis.get(PG_READONLY_MODE_KEY).present?
  end

  # Shared between processes
  def self.postgres_last_read_only
    @postgres_last_read_only ||= DistributedCache.new('postgres_last_read_only', namespace: false)
  end

  # Per-process
  def self.redis_last_read_only
    @redis_last_read_only ||= {}
  end

  def self.recently_readonly?
    postgres_read_only = postgres_last_read_only[Discourse.redis.namespace]
    redis_read_only = redis_last_read_only[Discourse.redis.namespace]

    (redis_read_only.present? && redis_read_only > 15.seconds.ago) ||
      (postgres_read_only.present? && postgres_read_only > 15.seconds.ago)
  end

  def self.received_postgres_readonly!
    postgres_last_read_only[Discourse.redis.namespace] = Time.zone.now
  end

  def self.received_redis_readonly!
    redis_last_read_only[Discourse.redis.namespace] = Time.zone.now
  end

  def self.clear_readonly!
    postgres_last_read_only[Discourse.redis.namespace] = redis_last_read_only[Discourse.redis.namespace] = nil
    Site.clear_anon_cache!
    true
  end

  def self.request_refresh!(user_ids: nil)
    # Causes refresh on next click for all clients
    #
    # This is better than `MessageBus.publish "/file-change", ["refresh"]` because
    # it spreads the refreshes out over a time period
    if user_ids
      MessageBus.publish("/refresh_client", 'clobber', user_ids: user_ids)
    else
      MessageBus.publish('/global/asset-version', 'clobber')
    end
  end

  def self.ensure_version_file_loaded
    unless @version_file_loaded
      version_file = "#{Rails.root}/config/version.rb"
      require version_file if File.exists?(version_file)
      @version_file_loaded = true
    end
  end

  def self.git_version
    ensure_version_file_loaded
    $git_version ||=
      begin
        git_cmd = 'git rev-parse HEAD'
        self.try_git(git_cmd, Discourse::VERSION::STRING)
      end # rubocop:disable Style/GlobalVars
  end

  def self.git_branch
    ensure_version_file_loaded
    $git_branch ||=
      begin
        git_cmd = 'git rev-parse --abbrev-ref HEAD'
        self.try_git(git_cmd, 'unknown')
      end
  end

  def self.full_version
    ensure_version_file_loaded
    $full_version ||=
      begin
        git_cmd = 'git describe --dirty --match "v[0-9]*"'
        self.try_git(git_cmd, 'unknown')
      end
  end

  def self.last_commit_date
    ensure_version_file_loaded
    $last_commit_date ||=
      begin
        git_cmd = 'git log -1 --format="%ct"'
        seconds = self.try_git(git_cmd, nil)
        seconds.nil? ? nil : DateTime.strptime(seconds, '%s')
      end
  end

  def self.try_git(git_cmd, default_value)
    version_value = false

    begin
      version_value = `#{git_cmd}`.strip
    rescue
      version_value = default_value
    end

    if version_value.empty?
      version_value = default_value
    end

    version_value
  end

  # Either returns the site_contact_username user or the first admin.
  def self.site_contact_user
    user = User.find_by(username_lower: SiteSetting.site_contact_username.downcase) if SiteSetting.site_contact_username.present?
    user ||= (system_user || User.admins.real.order(:id).first)
  end

  SYSTEM_USER_ID ||= -1

  def self.system_user
    @system_users ||= {}
    current_db = RailsMultisite::ConnectionManagement.current_db
    @system_users[current_db] ||= User.find_by(id: SYSTEM_USER_ID)
  end

  def self.store
    if SiteSetting.Upload.enable_s3_uploads
      @s3_store_loaded ||= require 'file_store/s3_store'
      FileStore::S3Store.new
    else
      @local_store_loaded ||= require 'file_store/local_store'
      FileStore::LocalStore.new
    end
  end

  def self.stats
    PluginStore.new("stats")
  end

  def self.current_user_provider
    @current_user_provider || Auth::DefaultCurrentUserProvider
  end

  def self.current_user_provider=(val)
    @current_user_provider = val
  end

  def self.asset_host
    Rails.configuration.action_controller.asset_host
  end

  def self.readonly_channel
    "/site/read-only"
  end

  # all forking servers must call this
  # after fork, otherwise Discourse will be
  # in a bad state
  def self.after_fork
    # note: some of this reconnecting may no longer be needed per https://github.com/redis/redis-rb/pull/414
    MessageBus.after_fork
    SiteSetting.after_fork
    Discourse.redis._client.reconnect
    Rails.cache.reconnect
    Discourse.cache.reconnect
    Logster.store.redis.reconnect
    # shuts down all connections in the pool
    Sidekiq.redis_pool.shutdown { |c| nil }
    # re-establish
    Sidekiq.redis = sidekiq_redis_config
    start_connection_reaper

    # in case v8 was initialized we want to make sure it is nil
    PrettyText.reset_context

    Tilt::ES6ModuleTranspilerTemplate.reset_context if defined? Tilt::ES6ModuleTranspilerTemplate
    JsLocaleHelper.reset_context if defined? JsLocaleHelper
    nil
  end

  # you can use Discourse.warn when you want to report custom environment
  # with the error, this helps with grouping
  def self.warn(message, env = nil)
    append = env ? (+" ") << env.map { |k, v|"#{k}: #{v}" }.join(" ") : ""

    if !(Logster::Logger === Rails.logger)
      Rails.logger.warn("#{message}#{append}")
      return
    end

    loggers = [Rails.logger]
    if Rails.logger.chained
      loggers.concat(Rails.logger.chained)
    end

    logster_env = env

    if old_env = Thread.current[Logster::Logger::LOGSTER_ENV]
      logster_env = Logster::Message.populate_from_env(old_env)

      # a bit awkward by try to keep the new params
      env.each do |k, v|
        logster_env[k] = v
      end
    end

    loggers.each do |logger|
      if !(Logster::Logger === logger)
        logger.warn("#{message} #{append}")
        next
      end

      logger.store.report(
        ::Logger::Severity::WARN,
        "discourse",
        message,
        env: logster_env
      )
    end

    if old_env
      env.each do |k, v|
        # do not leak state
        logster_env.delete(k)
      end
    end

    nil
  end

  # report a warning maintaining backtrack for logster
  def self.warn_exception(e, message: "", env: nil)
    if Rails.logger.respond_to? :add_with_opts

      env ||= {}
      env[:current_db] ||= RailsMultisite::ConnectionManagement.current_db

      # logster
      Rails.logger.add_with_opts(
        ::Logger::Severity::WARN,
        "#{message} : #{e}",
        "discourse-exception",
        backtrace: e.backtrace.join("\n"),
        env: env
      )
    else
      # no logster ... fallback
      Rails.logger.warn("#{message} #{e}")
    end
  rescue
    STDERR.puts "Failed to report exception #{e} #{message}"
  end

  def self.start_connection_reaper
    return if GlobalSetting.connection_reaper_age < 1 ||
              GlobalSetting.connection_reaper_interval < 1

    # this helps keep connection counts in check
    Thread.new do
      while true
        begin
          sleep GlobalSetting.connection_reaper_interval
          reap_connections(GlobalSetting.connection_reaper_age)
        rescue => e
          Discourse.warn_exception(e, message: "Error reaping connections")
        end
      end
    end
  end

  def self.reap_connections(idle)
    pools = []
    ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::ConnectionPool) { |pool| pools << pool }

    pools.each do |pool|
      # reap recovers connections that were aborted
      # eg a thread died or a dev forgot to check it in
      # flush removes idle connections
      # after fork we have "deadpools" so ignore them, they have been discarded
      # so @connections is set to nil
      if pool.connections
        pool.reap
        pool.flush(idle)
      end
    end
  end

  def self.deprecate(warning, drop_from: nil, since: nil, raise_error: false, output_in_test: false)
    location = caller_locations[1].yield_self { |l| "#{l.path}:#{l.lineno}:in \`#{l.label}\`" }
    warning = ["Deprecation notice:", warning]
    warning << "(deprecated since Discourse #{since})" if since
    warning << "(removal in Discourse #{drop_from})" if drop_from
    warning << "\nAt #{location}"
    warning = warning.join(" ")

    if raise_error
      raise Deprecation.new(warning)
    end

    if Rails.env == "development"
      STDERR.puts(warning)
    end

    if output_in_test && Rails.env == "test"
      STDERR.puts(warning)
    end

    digest = Digest::MD5.hexdigest(warning)
    redis_key = "deprecate-notice-#{digest}"

    if !Discourse.redis.without_namespace.get(redis_key)
      Rails.logger.warn(warning)
      begin
        Discourse.redis.without_namespace.setex(redis_key, 3600, "x")
      rescue Redis::CommandError => e
        raise unless e.message =~ /READONLY/
      end
    end
    warning
  end

  SIDEKIQ_NAMESPACE ||= 'sidekiq'.freeze

  def self.sidekiq_redis_config
    conf = GlobalSetting.redis_config.dup
    conf[:namespace] = SIDEKIQ_NAMESPACE
    conf
  end

  def self.static_doc_topic_ids
    [SiteSetting.tos_topic_id, SiteSetting.guidelines_topic_id, SiteSetting.privacy_topic_id]
  end

  cattr_accessor :last_ar_cache_reset

  def self.reset_active_record_cache_if_needed(e)
    last_cache_reset = Discourse.last_ar_cache_reset
    if e && e.message =~ /UndefinedColumn/ && (last_cache_reset.nil? || last_cache_reset < 30.seconds.ago)
      Rails.logger.warn "Clearing Active Record cache, this can happen if schema changed while site is running or in a multisite various databases are running different schemas. Consider running rake multisite:migrate."
      Discourse.last_ar_cache_reset = Time.zone.now
      Discourse.reset_active_record_cache
    end
  end

  def self.reset_active_record_cache
    ActiveRecord::Base.connection.query_cache.clear
    (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
      table.classify.constantize.reset_column_information rescue nil
    end
    nil
  end

  def self.running_in_rack?
    ENV["DISCOURSE_RUNNING_IN_RACK"] == "1"
  end

  def self.skip_post_deployment_migrations?
    ['1', 'true'].include?(ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"]&.to_s)
  end

  # this is used to preload as much stuff as possible prior to forking
  # in turn this can conserve large amounts of memory on forking servers
  def self.preload_rails!
    return if @preloaded_rails

    # load up all models and schema
    (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
      table.classify.constantize.first rescue nil
    end

    # ensure we have a full schema cache in case we missed something above
    ActiveRecord::Base.connection.data_sources.each do |table|
      ActiveRecord::Base.connection.schema_cache.add(table)
    end

    schema_cache = ActiveRecord::Base.connection.schema_cache

    # load up schema cache for all multisite assuming all dbs have
    # an identical schema
    RailsMultisite::ConnectionManagement.each_connection do
      dup_cache = schema_cache.dup
      # this line is not really needed, but just in case the
      # underlying implementation changes lets give it a shot
      dup_cache.connection = nil
      ActiveRecord::Base.connection.schema_cache = dup_cache
      I18n.t(:posts)

      # this will force Cppjieba to preload if any site has it
      # enabled allowing it to be reused between all child processes
      Search.prepare_data("test")
    end

    # router warm up
    Rails.application.routes.recognize_path('abc') rescue nil

    # preload discourse version
    Discourse.git_version
    Discourse.git_branch
    Discourse.full_version

    require 'actionview_precompiler'
    ActionviewPrecompiler.precompile
  ensure
    @preloaded_rails = true
  end

  def self.redis
    $redis
  end

  def self.is_parallel_test?
    ENV['RAILS_ENV'] == "test" && ENV['TEST_ENV_NUMBER']
  end
end

# rubocop:enable Style/GlobalVars
