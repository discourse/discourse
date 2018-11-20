require 'ostruct'

class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| send "#{key}=", value }
  end

  def self.auth_attributes
    [
      :pretty_name, # displayed pretty name string, needs to be localized string.
      :title,
      :message,
      :frame_width, # popup frame window size
      :frame_height,
      :authenticator, # authenticator class inheriented from lib/auth/authenticator.rb
      :pretty_name_setting,
      :title_setting,
      :enabled_setting,
      :full_screen_login,
      :full_screen_login_setting,
      :custom_url
    ]
  end

  def self.deprecated_auth_attributes
    [
      OpenStruct.new(attribute: :enabled_setting, version: "2.1.0", drop_version: "2.x.0", comment: "Please use authenticator.enabled? instead."),
      OpenStruct.new(attribute: :background_color, version: "2.1.0", drop_version: "2.x.0", comment: "Please use CSS for color and icons instead.")
    ]
  end

  attr_accessor(*auth_attributes)

  def name
    authenticator.name
  end

  def can_connect
    authenticator.can_connect_existing_user?
  end

  def can_revoke
    authenticator.can_revoke?
  end

end
