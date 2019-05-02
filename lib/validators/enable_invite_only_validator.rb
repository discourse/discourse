# frozen_string_literal: true

class EnableInviteOnlyValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    !SiteSetting.enable_sso?
  end

  def error_message
    I18n.t('site_settings.errors.sso_invite_only')
  end
end
