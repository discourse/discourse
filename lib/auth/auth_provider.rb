# frozen_string_literal: true

class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| public_send "#{key}=", value }
  end

  def self.auth_attributes
    [:pretty_name, :title, :message, :frame_width, :frame_height, :authenticator,
     :pretty_name_setting, :title_setting, :enabled_setting, :full_screen_login, :full_screen_login_setting,
     :custom_url, :background_color, :icon]
  end

  attr_accessor(*auth_attributes)

  def enabled_setting=(val)
    Discourse.deprecate("(#{authenticator.name}) enabled_setting is deprecated. Please define authenticator.enabled? instead")
    @enabled_setting = val
  end

  def background_color=(val)
    Discourse.deprecate("(#{authenticator.name}) background_color is no longer functional. Please use CSS instead")
  end

  def full_screen_login=(val)
    Discourse.deprecate("(#{authenticator.name}) full_screen_login is now forced. The full_screen_login parameter can be removed from the auth_provider.")
  end

  def full_screen_login_setting=(val)
    Discourse.deprecate("(#{authenticator.name}) full_screen_login is now forced. The full_screen_login_setting parameter can be removed from the auth_provider.")
  end

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
