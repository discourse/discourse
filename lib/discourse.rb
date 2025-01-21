# frozen_string_literal: true

require "cache"
require "open3"
require "plugin/instance"
require "version"
require "git_utils"

module Discourse
  DB_POST_MIGRATE_PATH = "db/post_migrate"
  REQUESTED_HOSTNAME = "REQUESTED_HOSTNAME"
  MAX_METADATA_FILE_SIZE = 64.kilobytes

  class Utils
    URI_REGEXP = URI.regexp(%w[http https])

    # TODO: Remove this once we drop support for Ruby 2.
    EMPTY_KEYWORDS = {}

    # Usage:
    #   Discourse::Utils.execute_command("pwd", chdir: 'mydirectory')
    # or with a block
    #   Discourse::Utils.execute_command(chdir: 'mydirectory') do |runner|
    #     runner.exec("pwd")
    #   end
    def self.execute_command(*command, **args)
      runner = CommandRunner.new(**args)

      if block_given?
        if command.present?
          raise RuntimeError.new("Cannot pass command and block to execute_command")
        end
        yield runner
      else
        runner.exec(*command)
      end
    end

    def self.pretty_logs(logs)
      logs.join("\n")
    end

    def self.logs_markdown(logs, user:, filename: "log.txt")
      # Reserve 250 characters for the rest of the text
      max_logs_length = SiteSetting.max_post_length - 250
      pretty_logs = Discourse::Utils.pretty_logs(logs)

      # If logs are short, try to inline them
      return <<~TEXT if pretty_logs.size < max_logs_length
        ```text
        #{pretty_logs}
        ```
        TEXT

      # Try to create an upload for the logs
      upload =
        Dir.mktmpdir do |dir|
          File.write(File.join(dir, filename), pretty_logs)
          zipfile = Compression::Zip.new.compress(dir, filename)
          File.open(zipfile) do |file|
            UploadCreator.new(
              file,
              File.basename(zipfile),
              type: "backup_logs",
              for_export: "true",
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

      FileUtils.mkdir_p(File.join(Rails.root, "tmp"))
      temp_destination = File.join(Rails.root, "tmp", SecureRandom.hex)

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

      FileUtils.mkdir_p(File.join(Rails.root, "tmp"))
      temp_destination = File.join(Rails.root, "tmp", SecureRandom.hex)
      execute_command("ln", "-s", source, temp_destination)
      FileUtils.mv(temp_destination, destination)

      nil
    end

    class CommandError < RuntimeError
      attr_reader :status, :stdout, :stderr
      def initialize(message, status: nil, stdout: nil, stderr: nil)
        super(message)
        @status = status
        @stdout = stdout
        @stderr = stderr
      end
    end

    private

    class CommandRunner
      def initialize(**init_params)
        @init_params = init_params
      end

      def exec(*command, **exec_params)
        if (@init_params.keys & exec_params.keys).present?
          raise RuntimeError.new("Cannot specify same parameters at block and command level")
        end
        execute_command(*command, **@init_params.merge(exec_params))
      end

      private

      def execute_command(
        *command,
        timeout: nil,
        failure_message: "",
        success_status_codes: [0],
        chdir: ".",
        unsafe_shell: false
      )
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
          raise CommandError.new(
                  "#{caller[0]}: #{failure_message}#{stderr}",
                  stdout: stdout,
                  stderr: stderr,
                  status: status,
                )
        end

        stdout
      end
    end
  end

  def self.job_exception_stats
    @job_exception_stats
  end

  def self.reset_job_exception_stats!
    @job_exception_stats = Hash.new(0)
  end

  reset_job_exception_stats!

  if Rails.env.test?
    def self.catch_job_exceptions!
      raise "tests only" if !Rails.env.test?
      @catch_job_exceptions = true
    end

    def self.reset_catch_job_exceptions!
      raise "tests only" if !Rails.env.test?
      remove_instance_variable(:@catch_job_exceptions)
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
    parent_logger ||= Sidekiq

    job = context[:job]

    # mini_scheduler direct reporting
    if Hash === job
      job_class = job["class"]
      job_exception_stats[job_class] += 1 if job_class
    end

    # internal reporting
    job_exception_stats[job] += 1 if job.class == Class && ::Jobs::Base > job

    cm = RailsMultisite::ConnectionManagement
    parent_logger.handle_exception(
      ex,
      { current_db: cm.current_db, current_hostname: cm.current_hostname }.merge(context),
    )

    raise ex if Rails.env.test? && !@catch_job_exceptions
  end

  # Expected less matches than what we got in a find
  class TooManyMatches < StandardError
  end

  # When they try to do something they should be logged in for
  class NotLoggedIn < StandardError
  end

  # When the input is somehow bad
  class InvalidParameters < StandardError
  end

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

    def initialize(
      msg = nil,
      status: 404,
      check_permalinks: false,
      original_path: nil,
      custom_message: nil
    )
      super(msg)

      @status = status
      @check_permalinks = check_permalinks
      @original_path = original_path
      @custom_message = custom_message
    end
  end

  # When a setting is missing
  class SiteSettingMissing < StandardError
  end

  # When ImageMagick is missing
  class ImageMagickMissing < StandardError
  end

  # When read-only mode is enabled
  class ReadOnly < StandardError
  end

  # Cross site request forgery
  class CSRF < StandardError
  end

  class Deprecation < StandardError
  end

  class ScssError < StandardError
  end

  def self.filters
    @filters ||= %i[latest unread new unseen top read posted bookmarks hot]
  end

  def self.anonymous_filters
    @anonymous_filters ||= %i[latest top categories hot]
  end

  def self.top_menu_items
    @top_menu_items ||= Discourse.filters + [:categories]
  end

  def self.anonymous_top_menu_items
    @anonymous_top_menu_items ||= Discourse.anonymous_filters + %i[categories top]
  end

  # list of pixel ratios Discourse tries to optimize for
  PIXEL_RATIOS = [1, 1.5, 2, 3]

  def self.avatar_sizes
    # TODO: should cache these when we get a notification system for site settings
    Set.new(SiteSetting.avatar_sizes.split("|").map(&:to_i))
  end

  def self.activate_plugins!
    @plugins = []
    @plugins_by_name = {}
    Plugin::Instance
      .find_all("#{Rails.root}/plugins")
      .each do |p|
        v = p.metadata.required_version || Discourse::VERSION::STRING
        if Discourse.has_needed_version?(Discourse::VERSION::STRING, v)
          p.activate!
          @plugins << p
          @plugins_by_name[p.name] = p

          # The plugin directory name and metadata name should match, but that
          # is not always the case
          dir_name = p.path.split("/")[-2]
          if p.name != dir_name
            STDERR.puts "Plugin name is '#{p.name}', but plugin directory is named '#{dir_name}'"
            # Plugins are looked up by directory name in SiteSettingExtension
            # because SiteSetting.load_settings uses directory name as plugin
            # name. We alias the two names just to make sure the look up works
            @plugins_by_name[dir_name] = p
          end
        else
          STDERR.puts "Could not activate #{p.metadata.name}, discourse does not meet required version (#{v})"
        end
      end
    DiscourseEvent.trigger(:after_plugin_activation)
  end

  def self.plugins
    @plugins ||= []
  end

  def self.plugins_by_name
    @plugins_by_name ||= {}
  end

  def self.visible_plugins
    plugins.filter(&:visible?)
  end

  def self.plugins_sorted_by_name(enabled_only: true)
    if enabled_only
      return visible_plugins.filter(&:enabled?).sort_by { |plugin| plugin.humanized_name.downcase }
    end
    visible_plugins.sort_by { |plugin| plugin.humanized_name.downcase }
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
    plugins.select { |plugin| plugin.asset_filters.all? { |b| b.call(type, request, filter_opts) } }
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
      assets +=
        plugins
          .find_all { |plugin| plugin.css_asset_exists?(target) }
          .map do |plugin|
            target.nil? ? plugin.directory_name : "#{plugin.directory_name}_#{target}"
          end
    end

    assets.map! { |asset| "#{asset}_rtl" } if args[:rtl]
    assets
  end

  def self.find_plugin_js_assets(args)
    plugins =
      self
        .find_plugins(args)
        .select do |plugin|
          plugin.js_asset_exists? || plugin.extra_js_asset_exists? || plugin.admin_js_asset_exists?
        end

    plugins = apply_asset_filters(plugins, :js, args[:request])

    plugins.flat_map do |plugin|
      assets = []
      assets << "plugins/#{plugin.directory_name}" if plugin.js_asset_exists?
      assets << "plugins/#{plugin.directory_name}_extra" if plugin.extra_js_asset_exists?
      # TODO: make admin asset only load for admins
      assets << "plugins/#{plugin.directory_name}_admin" if plugin.admin_js_asset_exists?
      assets
    end
  end

  def self.assets_digest
    @assets_digest ||=
      begin
        digest = Digest::MD5.hexdigest(ActionView::Base.assets_manifest.assets.values.sort.join)

        channel = "/global/asset-version"
        message = MessageBus.last_message(channel)

        MessageBus.publish channel, digest unless message && message.data == digest
        digest
      end
  end

  BUILTIN_AUTH = [
    Auth::AuthProvider.new(
      authenticator: Auth::FacebookAuthenticator.new,
      frame_width: 580,
      frame_height: 400,
      icon: "fab-facebook",
    ),
    Auth::AuthProvider.new(
      authenticator: Auth::GoogleOAuth2Authenticator.new,
      frame_width: 850,
      frame_height: 500,
    ), # Custom icon implemented in client
    Auth::AuthProvider.new(authenticator: Auth::GithubAuthenticator.new, icon: "fab-github"),
    Auth::AuthProvider.new(authenticator: Auth::TwitterAuthenticator.new, icon: "fab-twitter"),
    Auth::AuthProvider.new(authenticator: Auth::DiscordAuthenticator.new, icon: "fab-discord"),
    Auth::AuthProvider.new(
      authenticator: Auth::LinkedInOidcAuthenticator.new,
      icon: "fab-linkedin-in",
    ),
  ]

  def self.auth_providers
    BUILTIN_AUTH + DiscoursePluginRegistry.auth_providers.to_a
  end

  def self.enabled_auth_providers
    auth_providers.select { |provider| provider.authenticator.enabled? }
  end

  def self.authenticators
    # NOTE: this bypasses the site settings and gives a list of everything, we need to register every middleware
    #  for the cases of multisite
    auth_providers.map(&:authenticator)
  end

  def self.enabled_authenticators
    authenticators.select { |authenticator| authenticator.enabled? }
  end

  def self.cache
    @cache ||=
      begin
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
        require "socket"
        Socket.gethostname
      rescue => e
        warn_exception(e, message: "Socket.gethostname is not working")
        begin
          `hostname`.strip
        rescue => e
          warn_exception(e, message: "hostname command is not working")
          "unknown_host"
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

  def self.current_hostname_with_port
    default_port = SiteSetting.force_https? ? 443 : 80
    result = +"#{current_hostname}"
    if SiteSetting.port.to_i > 0 && SiteSetting.port.to_i != default_port
      result << ":#{SiteSetting.port}"
    end

    result << ":#{ENV["UNICORN_PORT"] || 3000}" if Rails.env.development? && SiteSetting.port.blank?

    result
  end

  def self.base_url_no_prefix
    "#{base_protocol}://#{current_hostname_with_port}"
  end

  def self.base_url
    base_url_no_prefix + base_path
  end

  def self.route_for(uri)
    unless uri.is_a?(URI)
      uri =
        begin
          URI(uri)
        rescue ArgumentError, URI::Error
        end
    end

    return unless uri

    path = +(uri.path || "")
    if !uri.host ||
         (uri.host == Discourse.current_hostname && path.start_with?(Discourse.base_path))
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

  def self.urls_cache
    @urls_cache ||= DistributedCache.new("urls_cache")
  end

  def self.tos_url
    if SiteSetting.tos_url.present?
      SiteSetting.tos_url
    else
      return urls_cache["tos"] if urls_cache["tos"].present?

      tos_url =
        if SiteSetting.tos_topic_id > 0 && Topic.exists?(id: SiteSetting.tos_topic_id)
          "#{Discourse.base_path}/tos"
        end

      if tos_url
        urls_cache["tos"] = tos_url
      else
        urls_cache.delete("tos")
      end
    end
  end

  def self.privacy_policy_url
    if SiteSetting.privacy_policy_url.present?
      SiteSetting.privacy_policy_url
    else
      return urls_cache["privacy_policy"] if urls_cache["privacy_policy"].present?

      privacy_policy_url =
        if SiteSetting.privacy_topic_id > 0 && Topic.exists?(id: SiteSetting.privacy_topic_id)
          "#{Discourse.base_path}/privacy"
        end

      if privacy_policy_url
        urls_cache["privacy_policy"] = privacy_policy_url
      else
        urls_cache.delete("privacy_policy")
      end
    end
  end

  def self.clear_urls!
    urls_cache.clear
  end

  LAST_POSTGRES_READONLY_KEY = "postgres:last_readonly"

  READONLY_MODE_KEY_TTL = 60
  READONLY_MODE_KEY = "readonly_mode"
  PG_READONLY_MODE_KEY = "readonly_mode:postgres"
  PG_READONLY_MODE_KEY_TTL = 300
  USER_READONLY_MODE_KEY = "readonly_mode:user"
  PG_FORCE_READONLY_MODE_KEY = "readonly_mode:postgres_force"

  # Pseudo readonly mode, where staff can still write
  STAFF_WRITES_ONLY_MODE_KEY = "readonly_mode:staff_writes_only"

  READONLY_KEYS = [
    READONLY_MODE_KEY,
    PG_READONLY_MODE_KEY,
    USER_READONLY_MODE_KEY,
    PG_FORCE_READONLY_MODE_KEY,
  ]

  def self.enable_readonly_mode(key = READONLY_MODE_KEY, expires: nil)
    if key == PG_READONLY_MODE_KEY || key == PG_FORCE_READONLY_MODE_KEY
      Sidekiq.pause!("pg_failover") if !Sidekiq.paused?
    end

    if expires.nil?
      expires = [
        USER_READONLY_MODE_KEY,
        PG_FORCE_READONLY_MODE_KEY,
        STAFF_WRITES_ONLY_MODE_KEY,
      ].exclude?(key)
    end

    if expires
      ttl =
        case key
        when PG_READONLY_MODE_KEY
          PG_READONLY_MODE_KEY_TTL
        else
          READONLY_MODE_KEY_TTL
        end

      Discourse.redis.setex(key, ttl, 1)
      keep_readonly_mode(key, ttl: ttl) if !Rails.env.test?
    else
      Discourse.redis.set(key, 1)
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
          while @dbs.size > 0
            sleep ttl / 2

            @mutex.synchronize do
              @dbs.each do |db|
                RailsMultisite::ConnectionManagement.with_connection(db) do
                  @dbs.delete(db) if !Discourse.redis.expire(key, ttl)
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
    recently_readonly? || GlobalSetting.pg_force_readonly_mode || Discourse.redis.exists?(*keys)
  end

  def self.staff_writes_only_mode?
    Discourse.redis.get(STAFF_WRITES_ONLY_MODE_KEY).present?
  end

  def self.pg_readonly_mode?
    Discourse.redis.get(PG_READONLY_MODE_KEY).present?
  end

  # Shared between processes
  def self.postgres_last_read_only
    @postgres_last_read_only ||= DistributedCache.new("postgres_last_read_only")
  end

  # Per-process
  def self.redis_last_read_only
    @redis_last_read_only ||= {}
  end

  def self.postgres_recently_readonly?
    seconds =
      postgres_last_read_only.defer_get_set("timestamp") { redis.get(LAST_POSTGRES_READONLY_KEY) }

    seconds ? Time.zone.at(seconds.to_i) > 15.seconds.ago : false
  end

  def self.recently_readonly?
    redis_read_only = redis_last_read_only[Discourse.redis.namespace]

    (redis_read_only.present? && redis_read_only > 15.seconds.ago) || postgres_recently_readonly?
  end

  def self.received_postgres_readonly!
    time = Time.zone.now
    redis.set(LAST_POSTGRES_READONLY_KEY, time.to_i.to_s)
    postgres_last_read_only.clear(after_commit: false)

    time
  end

  def self.clear_postgres_readonly!
    redis.del(LAST_POSTGRES_READONLY_KEY)
    postgres_last_read_only.clear(after_commit: false)
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
      MessageBus.publish("/refresh_client", "clobber", user_ids: user_ids)
    else
      MessageBus.publish("/global/asset-version", "clobber")
    end
  end

  def self.git_version
    @git_version ||= GitUtils.git_version
  end

  def self.git_branch
    @git_branch ||= GitUtils.git_branch
  end

  def self.full_version
    @full_version ||= GitUtils.full_version
  end

  def self.last_commit_date
    @last_commit_date ||= GitUtils.last_commit_date
  end

  def self.try_git(git_cmd, default_value)
    GitUtils.try_git(git_cmd, default_value)
  end

  # Either returns the site_contact_username user or the first admin.
  def self.site_contact_user
    user =
      User.find_by(
        username_lower: SiteSetting.site_contact_username.downcase,
      ) if SiteSetting.site_contact_username.present?
    user ||= (system_user || User.admins.real.order(:id).first)
  end

  SYSTEM_USER_ID = -1

  def self.system_user
    @system_users ||= {}
    current_db = RailsMultisite::ConnectionManagement.current_db
    @system_users[current_db] ||= User.find_by(id: SYSTEM_USER_ID)
  end

  def self.store
    if SiteSetting.Upload.enable_s3_uploads
      @s3_store_loaded ||= require "file_store/s3_store"
      FileStore::S3Store.new
    else
      @local_store_loaded ||= require "file_store/local_store"
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
  # before forking, otherwise the forked process might
  # be in a bad state
  def self.before_fork
    # V8 does not support forking, make sure all contexts are disposed
    ObjectSpace.each_object(MiniRacer::Context) { |c| c.dispose }

    # get rid of rubbish so we don't share it
    # longer term we will use compact! here
    GC.start
    GC.start
    GC.start
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
    Sidekiq.redis_pool.shutdown { |conn| conn.disconnect! }
    # re-establish
    Sidekiq.redis = sidekiq_redis_config

    # in case v8 was initialized we want to make sure it is nil
    PrettyText.reset_context

    DiscourseJsProcessor::Transpiler.reset_context if defined?(DiscourseJsProcessor::Transpiler)

    # warm up v8 after fork, that way we do not fork a v8 context
    # it may cause issues if bg threads in a v8 isolate randomly stop
    # working due to fork
    begin
      # Skip warmup in development mode - it makes boot take ~2s longer
      PrettyText.cook("warm up **pretty text**") if !Rails.env.development?
    rescue => e
      Rails.logger.error("Failed to warm up pretty text: #{e}\n#{e.backtrace.join("\n")}")
    end

    nil
  end

  # you can use Discourse.warn when you want to report custom environment
  # with the error, this helps with grouping
  def self.warn(message, env = nil)
    append = env ? (+" ") << env.map { |k, v| "#{k}: #{v}" }.join(" ") : ""

    loggers = Rails.logger.broadcasts
    logster_env = env

    if old_env = Thread.current[Logster::Logger::LOGSTER_ENV]
      logster_env = Logster::Message.populate_from_env(old_env)

      # a bit awkward by try to keep the new params
      env.each { |k, v| logster_env[k] = v }
    end

    loggers.each do |logger|
      if !(Logster::Logger === logger)
        logger.warn("#{message} #{append}")
        next
      end

      logger.store.report(::Logger::Severity::WARN, "discourse", message, env: logster_env)
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
        env: env,
      )
    else
      # no logster ... fallback
      Rails.logger.warn("#{message} #{e}\n#{e.backtrace.join("\n")}")
    end
  rescue StandardError
    STDERR.puts "Failed to report exception #{e} #{message}"
  end

  def self.capture_exceptions(message: "", env: nil)
    yield
  rescue Exception => e
    Discourse.warn_exception(e, message: message, env: env)
    nil
  end

  def self.deprecate(warning, drop_from: nil, since: nil, raise_error: false, output_in_test: false)
    location = caller_locations[1].yield_self { |l| "#{l.path}:#{l.lineno}:in \`#{l.label}\`" }
    warning = ["Deprecation notice:", warning]
    warning << "(deprecated since Discourse #{since})" if since
    warning << "(removal in Discourse #{drop_from})" if drop_from
    warning << "\nAt #{location}"
    warning = warning.join(" ")

    raise Deprecation.new(warning) if raise_error

    STDERR.puts(warning) if Rails.env.development?

    STDERR.puts(warning) if output_in_test && Rails.env.test?

    digest = Digest::MD5.hexdigest(warning)
    redis_key = "deprecate-notice-#{digest}"

    if !Rails.env.development? && Rails.logger && !GlobalSetting.skip_redis? &&
         !Discourse.redis.without_namespace.get(redis_key)
      Rails.logger.warn(warning)
      begin
        Discourse.redis.without_namespace.setex(redis_key, 3600, "x")
      rescue Redis::CommandError => e
        raise unless e.message =~ /READONLY/
      end
    end
    warning
  end

  SIDEKIQ_NAMESPACE = "sidekiq"

  def self.sidekiq_redis_config
    conf = GlobalSetting.redis_config.dup
    conf[:namespace] = SIDEKIQ_NAMESPACE
    conf
  end

  def self.static_doc_topic_ids
    [SiteSetting.tos_topic_id, SiteSetting.guidelines_topic_id, SiteSetting.privacy_topic_id]
  end

  def self.site_creation_date
    @creation_dates ||= {}
    current_db = RailsMultisite::ConnectionManagement.current_db
    @creation_dates[current_db] ||= begin
      result = DB.query_single <<~SQL
          SELECT created_at
          FROM schema_migration_details
          ORDER BY created_at
          LIMIT 1
        SQL
      result.first
    end
  end

  def self.clear_site_creation_date_cache
    @creation_dates = {}
  end

  cattr_accessor :last_ar_cache_reset

  def self.reset_active_record_cache_if_needed(e)
    last_cache_reset = Discourse.last_ar_cache_reset
    if e && e.message =~ /UndefinedColumn/ &&
         (last_cache_reset.nil? || last_cache_reset < 30.seconds.ago)
      Rails.logger.warn "Clearing Active Record cache, this can happen if schema changed while site is running or in a multisite various databases are running different schemas. Consider running rake multisite:migrate."
      Discourse.last_ar_cache_reset = Time.zone.now
      Discourse.reset_active_record_cache
    end
  end

  def self.reset_active_record_cache
    ActiveRecord::Base.connection.query_cache.clear
    (ActiveRecord::Base.connection.tables - %w[schema_migrations versions]).each do |table|
      begin
        table.classify.constantize.reset_column_information
      rescue StandardError
        nil
      end
    end
    nil
  end

  def self.running_in_rack?
    ENV["DISCOURSE_RUNNING_IN_RACK"] == "1"
  end

  def self.skip_post_deployment_migrations?
    %w[1 true].include?(ENV["SKIP_POST_DEPLOYMENT_MIGRATIONS"]&.to_s)
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
        begin
          table.classify.constantize.first
        rescue StandardError
          nil
        end
      end

      # ensure we have a full schema cache in case we missed something above
      ActiveRecord::Base.connection.data_sources.each do |table|
        ActiveRecord::Base.connection.schema_cache.add(table)
      end
    end

    RailsMultisite::ConnectionManagement.safe_each_connection do
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
      Thread.new do
        # router warm up
        begin
          Rails.application.routes.recognize_path("abc")
        rescue StandardError
          nil
        end
      end,
      Thread.new do
        # preload discourse version
        Discourse.git_version
        Discourse.git_branch
        Discourse.full_version
        Discourse.plugins.each { |p| p.commit_url }
      end,
      Thread.new do
        require "actionview_precompiler"
        ActionviewPrecompiler.precompile
      end,
      Thread.new { LetterAvatar.image_magick_version },
      Thread.new { SvgSprite.core_svgs },
      Thread.new { EmberCli.script_chunks },
    ].each(&:join)
  ensure
    @preloaded_rails = true
  end

  mattr_accessor :redis

  def self.is_parallel_test?
    ENV["RAILS_ENV"] == "test" && ENV["TEST_ENV_NUMBER"]
  end

  CDN_REQUEST_METHODS = %w[GET HEAD OPTIONS]

  def self.is_cdn_request?(env, request_method)
    return if CDN_REQUEST_METHODS.exclude?(request_method)

    cdn_hostnames = GlobalSetting.cdn_hostnames
    return if cdn_hostnames.blank?

    requested_hostname = env[REQUESTED_HOSTNAME] || env[Rack::HTTP_HOST]
    cdn_hostnames.include?(requested_hostname)
  end

  def self.apply_cdn_headers(headers)
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = CDN_REQUEST_METHODS.join(", ")
    headers
  end

  def self.allow_dev_populate?
    Rails.env.development? || ENV["ALLOW_DEV_POPULATE"] == "1"
  end

  # warning: this method is very expensive and shouldn't be called in places
  # where performance matters. it's meant to be called manually (e.g. in the
  # rails console) when dealing with an emergency that requires invalidating
  # theme cache
  def self.clear_all_theme_cache!
    ThemeField.force_recompilation!
    Theme.all.each(&:update_javascript_cache!)
    Theme.expire_site_cache!
  end

  def self.anonymous_locale(request)
    locale =
      HttpLanguageParser.parse(request.cookies["locale"]) if SiteSetting.set_locale_from_cookie
    locale ||=
      HttpLanguageParser.parse(
        request.env["HTTP_ACCEPT_LANGUAGE"],
      ) if SiteSetting.set_locale_from_accept_language_header
    locale
  end

  # For test environment only
  def self.enable_sidekiq_logging
    @@sidekiq_logging_enabled = true
  end

  # For test environment only
  def self.disable_sidekiq_logging
    @@sidekiq_logging_enabled = false
  end

  def self.enable_sidekiq_logging?
    ENV["DISCOURSE_LOG_SIDEKIQ"] == "1" ||
      (defined?(@@sidekiq_logging_enabled) && @@sidekiq_logging_enabled)
  end
end
