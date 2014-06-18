class UsernameSettingValidator
  def initialize(opts={})
    @opts = opts
  end

  def valid_value?(val)
    !val.present? || User.where(username: val).exists?
  end

  def error_message
    I18n.t('site_settings.errors.invalid_username')
  end
end
