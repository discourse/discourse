class EnableSsoValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == 'f'
    SiteSetting.sso_url.present?
  end

  def error_message
    I18n.t('site_settings.errors.sso_url_is_empty')
  end
end
