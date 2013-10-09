require 'cache'
require_dependency 'plugin/instance'
require_dependency 'auth/default_current_user_provider'

module Discourse

  # Expected less matches than what we got in a find
  class TooManyMatches < Exception; end

  # When they try to do something they should be logged in for
  class NotLoggedIn < Exception; end

  # When the input is somehow bad
  class InvalidParameters < Exception; end

  # When they don't have permission to do something
  class InvalidAccess < Exception; end

  # When something they want is not found
  class NotFound < Exception; end

  # When a setting is missing
  class SiteSettingMissing < Exception; end

  # Cross site request forgery
  class CSRF < Exception; end

  def self.activate_plugins!
    @plugins = Plugin::Instance.find_all("#{Rails.root}/plugins")
    @plugins.each do |plugin|
      plugin.activate!
    end
  end

  def self.plugins
    @plugins
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
    if plugins
      plugins.each do |p|
        next unless p.auth_providers
        p.auth_providers.each do |prov|
          providers << prov
        end
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

  def self.base_uri default_value=""
    if !ActionController::Base.config.relative_url_root.blank?
      return ActionController::Base.config.relative_url_root
    else
      return default_value
    end
  end

  def self.base_url_no_prefix
    default_port = 80
    protocol = "http"

    if SiteSetting.use_ssl?
      protocol = "https"
      default_port = 443
    end

    result = "#{protocol}://#{current_hostname}"

    port = SiteSetting.port.present? && SiteSetting.port.to_i > 0 ? SiteSetting.port.to_i : default_port

    result << ":#{SiteSetting.port}" if port != default_port
    result
  end

  def self.base_url
    return base_url_no_prefix + base_uri
  end

  def self.enable_maintenance_mode
    $redis.set maintenance_mode_key, 1
    true
  end

  def self.disable_maintenance_mode
    $redis.del maintenance_mode_key
    true
  end

  def self.maintenance_mode?
    !!$redis.get( maintenance_mode_key )
  end

  def self.git_version
    return $git_version if $git_version

    # load the version stamped by the "build:stamp" task
    f = Rails.root.to_s + "/config/version"
    require f if File.exists?("#{f}.rb")

    begin
      $git_version ||= `git rev-parse HEAD`.strip
    rescue
      $git_version = "unknown"
    end
  end

  # Either returns the site_contact_username user or the first admin.
  def self.site_contact_user
    user = User.where(username_lower: SiteSetting.site_contact_username).first if SiteSetting.site_contact_username.present?
    user ||= User.admins.real.order(:id).first
  end

  def self.system_user
    User.where(id: -1).first
  end

  def self.store
    if SiteSetting.enable_s3_uploads?
      @s3_store_loaded ||= require 'file_store/s3_store'
      S3Store.new
    else
      @local_store_loaded ||= require 'file_store/local_store'
      LocalStore.new
    end
  end

  def self.current_user_provider
    @current_user_provider || Auth::DefaultCurrentUserProvider
  end

  def self.current_user_provider=(val)
    @current_user_provider = val
  end

private

  def self.maintenance_mode_key
    'maintenance_mode'
  end
end
