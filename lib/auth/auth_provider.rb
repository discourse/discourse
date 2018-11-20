class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| send "#{key}=", value }
  end

  def self.auth_attributes
    [:pretty_name, :title, :message, :frame_width, :frame_height, :authenticator,
     :pretty_name_setting, :title_setting, :enabled_setting, :full_screen_login, :full_screen_login_setting,
     :custom_url]
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
