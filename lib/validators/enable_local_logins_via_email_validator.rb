class EnableLocalLoginsViaEmailValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    SiteSetting.enable_local_logins
  end

  def error_message
    I18n.t('site_settings.errors.enable_local_logins_disabled')
  end
end
