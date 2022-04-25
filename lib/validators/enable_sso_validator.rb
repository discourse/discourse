# frozen_string_literal: true

class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    return false if SiteSetting.discourse_connect_url.blank? || SiteSetting.invite_only? || is_2fa_enforced?
    true
  end

  def error_message
    return I18n.t('site_settings.errors.discourse_connect_url_is_empty') if SiteSetting.discourse_connect_url.blank?
    return I18n.t('site_settings.errors.discourse_connect_invite_only') if SiteSetting.invite_only?
    return I18n.t('site_settings.errors.discourse_connect_cannot_be_enabled_if_second_factor_enforced') if is_2fa_enforced?
  end

  def is_2fa_enforced?
    SiteSetting.enforce_second_factor? != 'no'
  end
end
