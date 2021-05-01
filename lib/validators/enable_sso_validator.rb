# frozen_string_literal: true

class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    return false if SiteSetting.discourse_connect_url.blank? || SiteSetting.invite_only?
    true
  end

  def error_message
    return I18n.t('site_settings.errors.discourse_connect_url_is_empty') if SiteSetting.discourse_connect_url.blank?
    return I18n.t('site_settings.errors.discourse_connect_invite_only') if SiteSetting.invite_only?
  end
end
