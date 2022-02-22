# frozen_string_literal: true

require 'cache'
require 'open3'
require_dependency 'plugin/instance'
require_dependency 'version'

module Discourse
  DB_POST_MIGRATE_PATH ||= "db/post_migrate"
  REQUESTED_HOSTNAME ||= "REQUESTED_HOSTNAME"

  require 'sidekiq/exception_handler'
  class SidekiqExceptionHandler
    extend Sidekiq::ExceptionHandler
  end

  class Utils
    URI_REGEXP ||= URI.regexp(%w{http https})

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
      logs.join("\n")
    end

    def self.logs_markdown(logs, user:, filename: 'log.txt')
      # Reserve 250 characters for the rest of the text
      max_logs_length = SiteSetting.max_post_length - 250
      pretty_logs = Discourse::Utils.pretty_logs(logs)

      # If logs are short, try to inline them
      if pretty_logs.size < max_logs_length
        return <<~TEXT
        ```text
        #{pretty_logs}
        ```
        TEXT
      end

      # Try to create an upload for the logs
      upload = Dir.mktmpdir do |dir|
        File.write(File.join(dir, filename), pretty_logs)
        zipfile = Compression::Zip.new.compress(dir, filename)
        File.open(zipfile) do |file|
          UploadCreator.new(
            file,
            File.basename(zipfile),
            type: 'backup_logs',
            for_export: 'true'
          ).create_for(user.id)
        end
      end

      if upload.persisted?
        return UploadMarkdown.new(upload).attachment_markdown
      else
        Rails.logger.warn("Failed to upload the backup logs file: #{upload.errors.full_messages}")
      end

      # If logs are long and upload cannot be created, show trimmed logs
      <<~TEXT
      ```text
      ...
      #{pretty_logs.last(max_logs_length)}
      ```
      TEXT
    end

    def self.atomic_write_file(destination, contents)
      begin
        return if File.read(destination) == contents
      rescue Errno::ENOENT
      end

      FileUtils.mkdir_p(File.join(Rails.root, 'tmp'))
      temp_destination = File.join(Rails.root, 'tmp', SecureRandom.hex)

      File.open(temp_destination, "w") do |fd|
        fd.write(contents)
        fd.fsync()
      end

      FileUtils.mv(temp_destination, destination)

      nil
    end

    def self.atomic_ln_s(source, destination)
      begin
        return if File.readlink(destination) == source
      rescue Errno::ENOENT, Errno::EINVAL
      end

      FileUtils.mkdir_p(File.join(Rails.root, 'tmp'))
      temp_destination = File.join(Rails.root, 'tmp', SecureRandom.hex)
      execute_command('ln', '-s', source, temp_destination)
      FileUtils.mv(temp_destination, destination)

      nil
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

      def execute_command(*command, timeout: nil, failure_message: "", success_status_codes: [0], chdir: ".", unsafe_shell: false)
        env = nil
        env = command.shift if command[0].is_a?(Hash)

        if !unsafe_shell && (command.length == 1) && command[0].include?(" ")
          # Sending a single string to Process.spawn will launch a shell
          # This means various things (e.g. subshells) are possible, and could present injection risk
          raise "Arguments should be provided as separate strings"
        end

        if timeout
          # will send a TERM after timeout
          # will send a KILL after timeout * 2
          command = ["timeout", "-k", "#{timeout.to_f * 2}", timeout.to_s] + command
        end

        args = command
        args = [env] + command if env
        stdout, stderr, status = Open3.capture3(*args, chdir: chdir)

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
    attr_reader :custom_message_params
    attr_reader :group

    def initialize(msg = nil, obj = nil, opts = nil)
      super(msg)

      @opts = opts || {}
      @obj = obj
      @custom_message = opts[:custom_message] if @opts[:custom_message]
      @custom_message_params = opts[:custom_message_params] if @opts[:custom_message_params]
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
    @filters ||= [:latest, :unread, :new, :unseen, :top, :read, :posted, :bookmarks]
  end

  def self.anonymous_filters
    @anonymous_filters ||= [:latest, :top, :categories]
  end

  def self.top_menu_items
    @top_menu_items ||= Discourse.filters + [:categories]
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

  def self.apply_asset_filters(plugins, type, request)
    filter_opts = asset_filter_options(type, request)
    plugins.select do |plugin|
      plugin.asset_filters.all? { |b| b.call(type, request, filter_opts) }
    end
  end

  def self.asset_filter_options(type, request)
    result = {}
    return result if request.blank?

    path = request.fullpath
    result[:path] = path if path.present?

    result
  end

  def self.find_plugin_css_assets(args)
    plugins = apply_asset_filters(self.find_plugins(args), :css, args[:request])

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
    plugins = self.find_plugins(args).select do |plugin|
      plugin.js_asset_exists?
    end

    plugins = apply_asset_filters(plugins, :js, args[:request])

    plugins.map { |plugin| "plugins/#{plugin.directory_name}" }
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

  # hostname of the server, operating system level
  # called os_hostname so we do no confuse it with current_hostname
  def self.os_hostname
    @os_hostname ||=
      begin
        require 'socket'
        Socket.gethostname
      rescue => e
        warn_exception(e, message: 'Socket.gethostname is not working')
        begin
          `hostname`.strip
        rescue => e
          warn_exception(e, message: 'hostname command is not working')
          'unknown_host'
        end
      end
  end

  # Get the current base URL for the current site
  def self.current_hostname
    SiteSetting.force_hostname.presence || RailsMultisite::ConnectionManagement.current_hostname
  end

  def self.base_path(default_value = "")
    ActionController::Base.config.relative_url_root.presence || default_value
  end

  def self.base_uri(default_value = "")
    deprecate("Discourse.base_uri is deprecated, use Discourse.base_path instead")
    base_path(default_value)
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
    base_url_no_prefix + base_path
  end

  def self.route_for(uri)
    unless uri.is_a?(URI)
      uri = begin
        URI(uri)
      rescue ArgumentError, URI::Error
      end
    end

    return unless uri

    path = +(uri.path || "")
    if !uri.host || (uri.host == Discourse.current_hostname && path.start_with?(Discourse.base_path))
      path.slice!(Discourse.base_path)
      return Rails.application.routes.recognize_path(path)
    end

    nil
  rescue ActionController::RoutingError
    nil
  end

  class << self
    alias_method :base_url_no_path, :base_url_no_prefix
  end

  READONLY_MODE_KEY_TTL      ||= 60
  READONLY_MODE_KEY          ||= 'readonly_mode'
  PG_READONLY_MODE_KEY       ||= 'readonly_mode:postgres'
  PG_READONLY_MODE_KEY_TTL   ||= 300
  USER_READONLY_MODE_KEY     ||= 'readonly_mode:user'
  PG_FORCE_READONLY_MODE_KEY ||= 'readonly_mode:postgres_force'

  READONLY_KEYS ||= [
    READONLY_MODE_KEY,
    PG_READONLY_MODE_KEY,
    USER_READONLY_MODE_KEY,
    PG_FORCE_READONLY_MODE_KEY
  ]

  def self.enable_readonly_mode(key = READONLY_MODE_KEY)
    if key == PG_READONLY_MODE_KEY || key == PG_FORCE_READONLY_MODE_KEY
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
    end

    if key == USER_READONLY_MODE_KEY || key == PG_FORCE_READONLY_MODE_KEY
      Discourse.redis.set(key, 1)
    else
      ttl =
        case key
        when PG_READONLY_MODE_KEY
          PG_READONLY_MODE_KEY_TTL
        else
          READONLY_MODE_KEY_TTL
        end

      Discourse.redis.setex(key, ttl, 1)
      keep_readonly_mode(key, ttl: ttl) if !Rails.env.test?
    end

    MessageBus.publish(readonly_channel, true)
    true
  end

  def self.keep_readonly_mode(key, ttl:)
    # extend the expiry by ttl minute every ttl/2 seconds
    @mutex ||= Mutex.new

    @mutex.synchronize do
      @dbs ||= Set.new
      @dbs << RailsMultisite::ConnectionManagement.current_db
      @threads ||= {}

      unless @threads[key]&.alive?
        @threads[key] = Thread.new do
          while @dbs.size > 0 do
            sleep ttl / 2

            @mutex.synchronize do
              @dbs.each do |db|
                RailsMultisite::ConnectionManagement.with_connection(db) do
                  if !Discourse.redis.expire(key, ttl)
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
    if key == PG_READONLY_MODE_KEY || key == PG_FORCE_READONLY_MODE_KEY
      Sidekiq.unpause! if Sidekiq.paused?
    end

    Discourse.redis.del(key)
    MessageBus.publish(readonly_channel, false)
    true
  end

  def self.enable_pg_force_readonly_mode
    RailsMultisite::ConnectionManagement.each_connection do
      enable_readonly_mode(PG_FORCE_READONLY_MODE_KEY)
    end

    true
  end

  def self.disable_pg_force_readonly_mode
    RailsMultisite::ConnectionManagement.each_connection do
      disable_readonly_mode(PG_FORCE_READONLY_MODE_KEY)
    end

    true
  end

  def self.readonly_mode?(keys = READONLY_KEYS)
    recently_readonly? || Discourse.redis.exists?(*keys)
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

  def self.clear_postgres_readonly!
    postgres_last_read_only[Discourse.redis.namespace] = nil
  end

  def self.received_redis_readonly!
    redis_last_read_only[Discourse.redis.namespace] = Time.zone.now
  end

  def self.clear_redis_readonly!
    redis_last_read_only[Discourse.redis.namespace] = nil
  end

  def self.clear_readonly!
    clear_redis_readonly!
    clear_postgres_readonly!
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

  def self.git_version
    @git_version ||= begin
      git_cmd = 'git rev-parse HEAD'
      self.try_git(git_cmd, Discourse::VERSION::STRING)
    end
  end

  def self.git_branch
    @git_branch ||= begin
      git_cmd = 'git rev-parse --abbrev-ref HEAD'
      self.try_git(git_cmd, 'unknown')
    end
  end

  def self.full_version
    @full_version ||= begin
      git_cmd = 'git describe --dirty --match "v[0-9]*" 2> /dev/null'
      self.try_git(git_cmd, 'unknown')
    end
  end

  def self.last_commit_date
    @last_commit_date ||= begin
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
    Discourse.redis.reconnect
    Rails.cache.reconnect
    Discourse.cache.reconnect
    Logster.store.redis.reconnect
    # shuts down all connections in the pool
    Sidekiq.redis_pool.shutdown { |conn| conn.disconnect!  }
    # re-establish
    Sidekiq.redis = sidekiq_redis_config

    # in case v8 was initialized we want to make sure it is nil
    PrettyText.reset_context

    DiscourseJsProcessor::Transpiler.reset_context if defined? DiscourseJsProcessor::Transpiler
    JsLocaleHelper.reset_context if defined? JsLocaleHelper

    # warm up v8 after fork, that way we do not fork a v8 context
    # it may cause issues if bg threads in a v8 isolate randomly stop
    # working due to fork
    begin
      # Skip warmup in development mode - it makes boot take ~2s longer
      PrettyText.cook("warm up **pretty text**") if !Rails.env.development?
    rescue => e
      Rails.logger.error("Failed to warm up pretty text: #{e}")
    end

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
        "#{message} : #{e.class.name} : #{e}",
        "discourse-exception",
        backtrace: e.backtrace.join("\n"),
        env: env
      )
    else
      # no logster ... fallback
      Rails.logger.warn("#{message} #{e}\n#{e.backtrace.join("\n")}")
    end
  rescue
    STDERR.puts "Failed to report exception #{e} #{message}"
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

    if Rails.logger && !Discourse.redis.without_namespace.get(redis_key)
      Rails.logger.warn(warning)
      begin
        Discourse.redis.without_namespace.setex(redis_key, 3600, "x")
      rescue Redis::CommandError => e
        raise unless e.message =~ /READONLY/
      end
    end
    warning
  end

  SIDEKIQ_NAMESPACE ||= 'sidekiq'

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

    if !Rails.env.development?
      # Skipped in development because the schema cache gets reset on every code change anyway
      # Better to rely on the filesystem-based db:schema:cache:dump

      # load up all models and schema
      (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
        table.classify.constantize.first rescue nil
      end

      # ensure we have a full schema cache in case we missed something above
      ActiveRecord::Base.connection.data_sources.each do |table|
        ActiveRecord::Base.connection.schema_cache.add(table)
      end
    end

    schema_cache = ActiveRecord::Base.connection.schema_cache

    RailsMultisite::ConnectionManagement.safe_each_connection do
      # load up schema cache for all multisite assuming all dbs have
      # an identical schema
      dup_cache = schema_cache.dup
      # this line is not really needed, but just in case the
      # underlying implementation changes lets give it a shot
      dup_cache.connection = nil
      ActiveRecord::Base.connection.schema_cache = dup_cache
      I18n.t(:posts)

      # this will force Cppjieba to preload if any site has it
      # enabled allowing it to be reused between all child processes
      Search.prepare_data("test")

      JsLocaleHelper.load_translations(SiteSetting.default_locale)
      Site.json_for(Guardian.new)
      SvgSprite.preload

      begin
        SiteSetting.client_settings_json
      rescue => e
        # Rescue from Redis related errors so that we can still boot the
        # application even if Redis is down.
        warn_exception(e, message: "Error while preloading client settings json")
      end
    end

    [
      Thread.new {
        # router warm up
        Rails.application.routes.recognize_path('abc') rescue nil
      },
      Thread.new {
        # preload discourse version
        Discourse.git_version
        Discourse.git_branch
        Discourse.full_version
      },
      Thread.new {
        require 'actionview_precompiler'
        ActionviewPrecompiler.precompile
      },
      Thread.new {
        LetterAvatar.image_magick_version
      },
      Thread.new {
        SvgSprite.core_svgs
      }
    ].each(&:join)
  ensure
    @preloaded_rails = true
  end

  mattr_accessor :redis

  def self.is_parallel_test?
    ENV['RAILS_ENV'] == "test" && ENV['TEST_ENV_NUMBER']
  end

  CDN_REQUEST_METHODS ||= ["GET", "HEAD", "OPTIONS"]

  def self.is_cdn_request?(env, request_method)
    return unless CDN_REQUEST_METHODS.include?(request_method)

    cdn_hostnames = GlobalSetting.cdn_hostnames
    return if cdn_hostnames.blank?

    requested_hostname = env[REQUESTED_HOSTNAME] || env[Rack::HTTP_HOST]
    cdn_hostnames.include?(requested_hostname)
  end

  def self.apply_cdn_headers(headers)
    headers['Access-Control-Allow-Origin'] = '*'
    headers['Access-Control-Allow-Methods'] = CDN_REQUEST_METHODS.join(", ")
    headers
  end

  def self.allow_dev_populate?
    Rails.env.development? || ENV["ALLOW_DEV_POPULATE"] == "1"
  end
end
