module UserAuthTokensMixin
  extend ActiveSupport::Concern

  included do
    attributes :id,
               :client_ip,
               :os,
               :device_name,
               :icon,
               :created_at
  end

  def client_ip
    object.client_ip.to_s
  end

  def os
    case object.user_agent
    when /Android/i
      'Android'
    when /iPhone|iPad|iPod/i
      'iOS'
    when /Macintosh/i
      'macOS'
    when /Linux/i
      'Linux'
    when /Windows/i
      'Windows'
    else
      I18n.t('staff_action_logs.unknown')
    end
  end

  def device_name
    case object.user_agent
    when /Android/i
      I18n.t('user_auth_tokens.devices.android')
    when /iPad/i
      I18n.t('user_auth_tokens.devices.ipad')
    when /iPhone/i
      I18n.t('user_auth_tokens.devices.iphone')
    when /iPod/i
      I18n.t('user_auth_tokens.devices.ipod')
    when /Mobile/i
      I18n.t('user_auth_tokens.devices.mobile')
    when /Macintosh/i
      I18n.t('user_auth_tokens.devices.mac')
    when /Linux/i
      I18n.t('user_auth_tokens.devices.linux')
    when /Windows/i
      I18n.t('user_auth_tokens.devices.windows')
    else
      I18n.t('user_auth_tokens.devices.unknown')
    end
  end

  def icon
    case os
    when 'Android'
      'android'
    when 'macOS', 'iOS'
      'apple'
    when 'Linux'
      'linux'
    when 'Windows'
      'windows'
    else
      'question'
    end
  end
end
