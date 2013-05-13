require 'cache'

module Discourse

  # When they try to do something they should be logged in for
  class NotLoggedIn < Exception; end

  # When the input is somehow bad
  class InvalidParameters < Exception; end

  # When they don't have permission to do something
  class InvalidAccess < Exception; end

  # When something they want is not found
  class NotFound < Exception; end

  def self.cache
    @cache ||= Cache.new
  end

  # Get the current base URL for the current site
  def self.current_hostname
    RailsMultisite::ConnectionManagement.current_hostname
  end

  def self.base_uri default_value=""
    if !ActionController::Base.config.relative_url_root.blank?
      return ActionController::Base.config.relative_url_root
    else
      return default_value
    end
  end

  def self.base_url_no_prefix
    protocol = "http"
    protocol = "https" if SiteSetting.use_ssl?
    if SiteSetting.force_hostname.present?
      result = "#{protocol}://#{SiteSetting.force_hostname}"
    else
      result = "#{protocol}://#{current_hostname}"
    end
    result << ":#{SiteSetting.port}" if SiteSetting.port.present? && SiteSetting.port.to_i > 0
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
    f = Rails.root.to_s + "/config/version"
    require f if File.exists?("#{f}.rb")

    begin
      $git_version ||= `git rev-parse HEAD`.strip
    rescue
      $git_version = "unknown"
    end
  end


private

  def self.maintenance_mode_key
    'maintenance_mode'
  end
end
