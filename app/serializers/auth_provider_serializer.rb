# frozen_string_literal: true

class AuthProviderSerializer < ApplicationSerializer

  attributes :name, :custom_url, :pretty_name_override, :title_override, :message_override,
             :frame_width, :frame_height, :can_connect, :can_revoke,
             :icon

  def title_override
    return SiteSetting.get(object.title_setting) if object.title_setting
    object.title
  end

  def pretty_name_override
    return SiteSetting.get(object.pretty_name_setting) if object.pretty_name_setting
    object.pretty_name
  end

  def message_override
    object.message
  end

end
