require_dependency 'browser_detection'
require_dependency 'discourse_ip_info'

module UserAuthTokensMixin
  extend ActiveSupport::Concern

  included do
    attributes :id,
               :client_ip,
               :location,
               :browser,
               :device,
               :os,
               :icon,
               :created_at
  end

  def client_ip
    object.client_ip.to_s
  end

  def location
    ipinfo = DiscourseIpInfo.get(client_ip, locale: I18n.locale)
    ipinfo[:location].presence || I18n.t('staff_action_logs.unknown')
  end

  def browser
    val = BrowserDetection.browser(object.user_agent)
    I18n.t("user_auth_tokens.browser.#{val}")
  end

  def device
    val = BrowserDetection.device(object.user_agent)
    I18n.t("user_auth_tokens.device.#{val}")
  end

  def os
    val = BrowserDetection.os(object.user_agent)
    I18n.t("user_auth_tokens.os.#{val}")
  end

  def icon
    case BrowserDetection.os(object.user_agent)
    when :android
      'android'
    when :macos, :ios
      'apple'
    when :linux
      'linux'
    when :windows
      'windows'
    else
      'question'
    end
  end
end
