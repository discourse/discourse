require 'cache'
require_dependency 'plugin/instance'
require_dependency 'auth/default_current_user_provider'
require_dependency 'version'

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
    attr_reader :obj
    def initialize(msg=nil, obj=nil)
      super(msg)
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

  PIXEL_RATIOS ||= [1, 2, 3]

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

  def self.recently_readonly?
    return false unless @last_read_only
    @last_read_only > 15.seconds.ago
  end

  def self.received_readonly!
    @last_read_only = Time.now
  end

  def self.clear_readonly!
    @last_read_only = nil
  end

  def self.disabled_plugin_names
    plugins.select {|p| !p.enabled?}.map(&:name)
  end

  def self.plugins
    @plugins ||= []
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
    if SiteSetting.force_hostname.present?
      SiteSetting.force_hostname
    else
      RailsMultisite::ConnectionManagement.current_hostname
    end
  end

  def self.base_uri(default_value = "")
    if !ActionController::Base.config.relative_url_root.blank?
      ActionController::Base.config.relative_url_root
    else
      default_value
    end
  end

  def self.base_url_no_prefix
    default_port = 80
    protocol = "http"

    if SiteSetting.use_https?
      protocol = "https"
      default_port = 443
    end

    result = "#{protocol}://#{current_hostname}"

    port = SiteSetting.port.present? && SiteSetting.port.to_i > 0 ? SiteSetting.port.to_i : default_port

    result << ":#{SiteSetting.port}" if port != default_port
    result
  end

  def self.base_url
    base_url_no_prefix + base_uri
  end

  def self.enable_readonly_mode
    $redis.set(readonly_mode_key, 1)
    MessageBus.publish(readonly_channel, true)
    keep_readonly_mode
    true
  end

  def self.keep_readonly_mode
    # extend the expiry by 1 minute every 30 seconds
    Thread.new do
      while readonly_mode?
        $redis.expire(readonly_mode_key, 1.minute)
        sleep 30.seconds
      end
    end
  end

  def self.disable_readonly_mode
    $redis.del(readonly_mode_key)
    MessageBus.publish(readonly_channel, false)
    true
  end

  def self.readonly_mode?
    recently_readonly? || !!$redis.get(readonly_mode_key)
  end

  def self.request_refresh!
    # Causes refresh on next click for all clients
    #
    # This is better than `MessageBus.publish "/file-change", ["refresh"]` because
    # it spreads the refreshes out over a time period
    MessageBus.publish '/global/asset-version', 'clobber'
  end

  def self.git_version
    return $git_version if $git_version

    # load the version stamped by the "build:stamp" task
    f = Rails.root.to_s + "/config/version"
    require f if File.exists?("#{f}.rb")

    begin
      $git_version ||= `git rev-parse HEAD`.strip
    rescue
      $git_version = Discourse::VERSION::STRING
    end
  end

  def self.git_branch
    return $git_branch if $git_branch

    begin
      $git_branch ||= `git rev-parse --abbrev-ref HEAD`.strip
    rescue
      $git_branch = "unknown"
    end
  end

  # Either returns the site_contact_username user or the first admin.
  def self.site_contact_user
    user = User.find_by(username_lower: SiteSetting.site_contact_username.downcase) if SiteSetting.site_contact_username.present?
    user ||= User.admins.real.order(:id).first
  end

  SYSTEM_USER_ID ||= -1

  def self.system_user
    User.find_by(id: SYSTEM_USER_ID)
  end

  def self.store
    if SiteSetting.enable_s3_uploads?
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

  def self.readonly_mode_key
    "readonly_mode"
  end

  def self.readonly_channel
    "/site/read-only"
  end

  # all forking servers must call this
  # after fork, otherwise Discourse will be
  # in a bad state
  def self.after_fork
    # note: all this reconnecting may no longer be needed per https://github.com/redis/redis-rb/pull/414
    current_db = RailsMultisite::ConnectionManagement.current_db
    RailsMultisite::ConnectionManagement.establish_connection(db: current_db)
    MessageBus.after_fork
    SiteSetting.after_fork
    $redis.client.reconnect
    Rails.cache.reconnect
    Logster.store.redis.reconnect
    # shuts down all connections in the pool
    Sidekiq.redis_pool.shutdown{|c| nil}
    # re-establish
    Sidekiq.redis = sidekiq_redis_config
    start_connection_reaper
    nil
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
          Discourse.handle_exception(e, {message: "Error reaping connections"})
        end
      end
    end
  end

  def self.reap_connections(age)
    pools = []
    ObjectSpace.each_object(ActiveRecord::ConnectionAdapters::ConnectionPool){|pool| pools << pool}

    pools.each do |pool|
      pool.drain(age.seconds)
    end
  end

  def self.sidekiq_redis_config
    conf = GlobalSetting.redis_config.dup
    conf[:namespace] = 'sidekiq'
    conf
  end

  def self.static_doc_topic_ids
    [SiteSetting.tos_topic_id, SiteSetting.guidelines_topic_id, SiteSetting.privacy_topic_id]
  end

end
