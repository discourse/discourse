# frozen_string_literal: true

class Auth::AuthProvider
  include ActiveModel::Serialization

  def initialize(params = {})
    params.each { |key, value| public_send "#{key}=", value }
  end

  def self.auth_attributes
    %i[
      authenticator
      pretty_name
      title
      message
      frame_width
      frame_height
      pretty_name_setting
      title_setting
      full_screen_login
      full_screen_login_setting
      custom_url
      background_color
      icon
    ]
  end

  attr_accessor(*auth_attributes)

  def background_color=(val)
    Discourse.deprecate(
      "(#{authenticator.name}) background_color is no longer functional. Please use CSS instead",
      drop_from: "2.9.0",
    )
  end

  def full_screen_login=(val)
    Discourse.deprecate(
      "(#{authenticator.name}) full_screen_login is now forced. The full_screen_login parameter can be removed from the auth_provider.",
      drop_from: "2.9.0",
    )
  end

  def full_screen_login_setting=(val)
    Discourse.deprecate(
      "(#{authenticator.name}) full_screen_login is now forced. The full_screen_login_setting parameter can be removed from the auth_provider.",
      drop_from: "2.9.0",
    )
  end

  def message=(val)
    Discourse.deprecate(
      "(#{authenticator.name}) message is no longer used because all logins are full screen. It should be removed from the auth_provider",
      drop_from: "2.9.0",
    )
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
