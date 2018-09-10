class AuthProviderSerializer < ApplicationSerializer

  attributes :name, :custom_url, :pretty_name_override, :title_override, :message_override,
             :frame_width, :frame_height, :full_screen_login, :can_connect, :can_revoke

  def title_override
    return SiteSetting.send(object.title_setting) if object.title_setting
    object.title
  end

  def pretty_name_override
    return SiteSetting.send(object.pretty_name_setting) if object.pretty_name_setting
    object.pretty_name
  end

  def full_screen_login
    return SiteSetting.send(object.full_screen_login_setting) if object.full_screen_login_setting
    return object.full_screen_login if object.full_screen_login
    false
  end

  def message_override
    object.message
  end

end
