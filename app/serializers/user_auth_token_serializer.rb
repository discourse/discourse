class UserAuthTokenSerializer < ApplicationSerializer
  attributes :id,
             :action,
             :client_ip,
             :created_at,
             :seen_at,
             :os,
             :device_name,
             :icon

  def action
    case object.action
    when 'generate'
      I18n.t('log_in')
    when 'destroy'
      I18n.t('unsubscribe.log_out')
    else
      I18n.t('staff_action_logs.unknown')
    end
  end

  def include_action?
    object.has_attribute?(:action)
  end

  def client_ip
    object.client_ip.to_s
  end

  def include_seen_at?
    object.has_attribute?(:seen_at)
  end

  def os
    case object.user_agent
    when /Android/i
      'Android'
    when /Linux/i
      'Linux'
    when /Windows/i
      'Windows'
    when /Macintosh|Mac OS X|macOS/i
      'macOS'
    when /iPhone|iPad|iPod/i
      'iOS'
    else
      I18n.t('staff_action_logs.unknown')
    end
  end

  def device_name
    case object.user_agent
    when /Android/i
      I18n.t('user_auth_tokens.devices.android')
    when /Linux/i
      I18n.t('user_auth_tokens.devices.linux')
    when /Windows/i
      I18n.t('user_auth_tokens.devices.windows')
    when /Macintosh|Mac OS X|macOS/i
      I18n.t('user_auth_tokens.devices.mac')
    when /iPhone/i
      I18n.t('user_auth_tokens.devices.iphone')
    when /iPad/i
      I18n.t('user_auth_tokens.devices.ipad')
    when /iPod/i
      I18n.t('user_auth_tokens.devices.ipod')
    when /Mobile/i
      I18n.t('user_auth_tokens.devices.mobile')
    else
      I18n.t('user_auth_tokens.devices.unknown')
    end
  end

  def icon
    case os
    when 'Linux'
      'linux'
    when 'Windows'
      'windows'
    when 'macOS', 'iOS'
      'apple'
    when 'Android'
      'android'
    else
      'question'
    end
  end
end
