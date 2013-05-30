module Discourse

  # When they try to do something they should be logged in for
  class NotLoggedIn < Exception; end

  # When the input is somehow bad
  class InvalidParameters < Exception; end

  # When they don't have permission to do something
  class InvalidAccess < Exception; end

  # When something they want is not found
  class NotFound < Exception; end


  # Get the current base URL for the current site
  def self.current_hostname
    if SiteSetting.force_hostname.present?
      SiteSetting.force_hostname
    else
      RailsMultisite::ConnectionManagement.current_hostname
    end
  end

  def self.base_url
    default_port = 80
    protocol = "http"
    if SiteSetting.use_ssl?
      protocol = "https" 
      default_port = 443
    end

    result = "#{protocol}://#{current_hostname}"
    if SiteSetting.port.present? && SiteSetting.port.to_i > 0 && SiteSetting.port.to_i != default_port
      result << ":#{SiteSetting.port}" 
    end
    result
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
