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

  require 'sidekiq/exception_handler'
  class SidekiqExceptionHandler
    extend Sidekiq::ExceptionHandler
  end

  class Utils
    def self.execute_command(*command, failure_message: "")
      stdout, stderr, status = Open3.capture3(*command)

      if !status.success?
        failure_message = "#{failure_message}\n" if !failure_message.blank?
        raise "#{failure_message}#{stderr}"
      end

      stdout
    end

    def self.pretty_logs(logs)
      logs.join("\n".freeze)
    end
  end

  # Log an exception.
  #
  # If your code is in a scheduled job, it is recommended to use the
  # error_context() method in Jobs::Base to pass the job arguments and any
  # other desired context.
  # See app/jobs/base.rb for the error_context function.
  def self.handle_job_exception(ex, context = {}, parent_logger = nil)
    context ||= {}
    parent_logger ||= SidekiqExceptionHandler

    cm = RailsMultisite::ConnectionManagement
    parent_logger.handle_exception(ex, {
      current_db: cm.current_db,
      current_hostname: cm.current_hostname
    }.merge(context))
  end

  # Expected less matches than what we got in a find
  class TooManyMatches < StandardError; end

  # When they try to do something they should be logged in for
  class NotLoggedIn < StandardError; end

  # When the input is somehow bad
  class InvalidParameters < StandardError; end

  # When they don't have permission to do something
  class InvalidAccess < StandardError
    attr_reader :obj, :custom_message, :opts
    def initialize(msg = nil, obj = nil, opts = nil)
      super(msg)

      @opts = opts || {}
      @custom_message = opts[:custom_message] if @opts[:custom_message]
      @obj = obj
    end
  end

  # When something they want is not found
  class NotFound < StandardError; end

  # When a setting is missing
  class SiteSettingMissing < StandardError; end

  # When ImageMagick is missing
  class ImageMagickMissing < StandardError; end

  # When read-only mode is enabled
  class ReadOnly < StandardError; end

  # Cross site request forgery
  class CSRF < StandardError; end

  class Deprecation < StandardError; end

  def self.filters
    @filters ||= [:latest, :unread, :new, :read, :posted, :bookmarks]
  end

  def self.anonymous_filters
    @anonymous_filters ||= [:latest, :top, :categories]
  end

  def self.top_menu_items
    @top_menu_items ||= Discourse.filters + [:category, :categories, :top]
  end

  def self.anonymous_top_menu_items
    @anonymous_top_menu_items ||= Discourse.anonymous_filters + [:category, :categories, :top]
  end

  PIXEL_RATIOS ||= [1, 1.5, 2, 3]

  def self.avatar_sizes
    # TODO: should cache these when we get a notification system for site settings
    set = Set.new

    SiteSetting.avatar_sizes.split("|").map(&:to_i).each do |size|
      PIXEL_RATIOS.each do |pixel_ratio|
        set << size * pixel_ratio
      end
    end

    set
  end

  def self.activate_plugins!
    all_plugins = Plugin::Instance.find_all("#{Rails.root}/plugins")

    if Rails.env.development?
      plugin_hash = Digest::SHA1.hexdigest(all_plugins.map { |p| p.path }.sort.join('|'))
      hash_file = "#{Rails.root}/tmp/plugin-hash"

      old_hash = begin
        File.read(hash_file)
      rescue Errno::ENOENT
      end

      if old_hash && old_hash != plugin_hash
        puts "WARNING: It looks like your discourse plugins have recently changed."
        puts "It is highly recommended to remove your `tmp` directory, otherwise"
        puts "plugins might not work."
        puts
      else
        File.write(hash_file, plugin_hash)
      end
    end

    @plugins = []
    all_plugins.each do |p|
      v = p.metadata.required_version || Discourse::VERSION::STRING
      if Discourse.has_needed_version?(Discourse::VERSION::STRING, v)
        p.activate!
        @plugins << p
      else
        STDERR.puts "Could not activate #{p.metadata.name}, discourse does not meet required version (#{v})"
      end
    end
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

  def self.authenticators
    # TODO: perhaps we don't need auth providers and authenticators maybe one object is enough

    # NOTE: this bypasses the site settings and gives a list of everything, we need to register every middleware
    #  for the cases of multisite
    # In future we may change it so we don't include them all for cases where we are not a multisite, but we would
    #  require a restart after site settings change
    Users::OmniauthCallbacksController::BUILTIN_AUTH + auth_providers.map(&:authenticator)
  end

  def self.auth_providers
    providers = []
    plugins.each do |p|
      next unless p.auth_providers
      p.auth_providers.each do |prov|
        providers << prov
      end
    end
    providers
  end

  def self.cache
    @cache ||= Cache.new
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
    url = "#{base_protocol}://#{current_hostname}"
    url << ":#{SiteSetting.port}" if SiteSetting.port.to_i > 0 && SiteSetting.port.to_i != default_port
    url
  end

  def self.base_url
    base_url_no_prefix + base_uri
  end

  def self.route_for(uri)
    unless uri.is_a?(URI)
      uri = begin
        URI(uri)
      rescue URI::InvalidURIError
      end
    end

    return unless uri

    path = uri.path || ""
    if !uri.host || (uri.host == Discourse.current_hostname && path.start_with?(Discourse.base_uri))
      path.slice!(Discourse.base_uri)
      return Rails.application.routes.recognize_path(path)
    end

    nil
  rescue ActionController::RoutingError
    nil
  end

  READONLY_MODE_KEY_TTL  ||= 60
  READONLY_MODE_KEY      ||= 'readonly_mode'.freeze
  PG_READONLY_MODE_KEY   ||= 'readonly_mode:postgres'.freeze
  USER_READONLY_MODE_KEY ||= 'readonly_mode:user'.freeze

  READONLY_KEYS ||= [
    READONLY_MODE_KEY,
    PG_READONLY_MODE_KEY,
    USER_READONLY_MODE_KEY
  ]

  def self.enable_readonly_mode(key = READONLY_MODE_KEY)
    if key == USER_READONLY_MODE_KEY
      $redis.set(key, 1)
    else
      $redis.setex(key, READONLY_MODE_KEY_TTL, 1)
      keep_readonly_mode(key)
    end

    MessageBus.publish(readonly_channel, true)
    true
  end

  def self.keep_readonly_mode(key)
    # extend the expiry by 1 minute every 30 seconds
    unless Rails.env.test?
      @dbs ||= Set.new
      @dbs << RailsMultisite::ConnectionManagement.current_db
      @threads ||= {}

      unless @threads[key]&.alive?
        @threads[key] = Thread.new do
          while @dbs.size > 0
            sleep 30

            @dbs.each do |db|
              RailsMultisite::ConnectionManagement.with_connection(db) do
                if readonly_mode?(key)
                  $redis.expire(key, READONLY_MODE_KEY_TTL)
                else
                  @dbs.delete(db)
                end
              end
            end
          end
        end
      end
    end
  end

  def self.disable_readonly_mode(key = READONLY_MODE_KEY)
    $redis.del(key)
    MessageBus.publish(readonly_channel, false)
    true
  end

  def self.readonly_mode?(keys = READONLY_KEYS)
    recently_readonly? || $redis.mget(*keys).compact.present?
  end

  def self.last_read_only
    @last_read_only ||= {}
  end

  def self.recently_readonly?
    return false unless read_only = last_read_only[$redis.namespace]
    read_only > 15.seconds.ago
  end

  def self.received_readonly!
    last_read_only[$redis.namespace] = Time.zone.now
  end

  def self.clear_readonly!
    last_read_only[$redis.namespace] = nil
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
      end
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
    @system_user ||= User.find_by(id: SYSTEM_USER_ID)
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
    $redis._client.reconnect
    Rails.cache.reconnect
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

  def self.deprecate(warning)
    location = caller_locations[1]
    warning = "Deprecation Notice: #{warning}\nAt: #{location.label} #{location.path}:#{location.lineno}"
    if Rails.env == "development"
      STDERR.puts(warning)
    end

    digest = Digest::MD5.hexdigest(warning)
    redis_key = "deprecate-notice-#{digest}"

    if !$redis.without_namespace.get(redis_key)
      Rails.logger.warn(warning)
      $redis.without_namespace.setex(redis_key, 3600, "x")
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

end
