# frozen_string_literal: true

class AuthProviderSerializer < ApplicationSerializer
  attributes :can_connect,
             :can_revoke,
             :custom_url,
             :frame_height,
             :frame_width,
             :icon_override,
             :name,
             :pretty_name_override,
             :provider_url,
             :title_override

  # ensures that the "/custom" route doesn't trigger the magic custom_url helper in ActionDispatch
  def custom_url
    object.custom_url
  end

  def pretty_name_override
    object.pretty_name_setting ? SiteSetting.get(object.pretty_name_setting) : object.pretty_name
  end

  def title_override
    object.title_setting ? SiteSetting.get(object.title_setting) : object.title
  end

  def icon_override
    object.icon_setting ? SiteSetting.get(object.icon_setting) : object.icon
  end
end
