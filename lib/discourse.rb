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
    RailsMultisite::ConnectionManagement.current_hostname
  end

  def self.base_url
    protocol = "http"
    protocol = "https" if SiteSetting.use_ssl?
    result = "#{protocol}://#{current_hostname}"    
    result << ":#{SiteSetting.port}" if SiteSetting.port.present?
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


private

  def self.maintenance_mode_key
    'maintenance_mode'
  end
end
