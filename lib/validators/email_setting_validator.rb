class EmailSettingValidator
  def self.valid_value?(val)
    !val.present? || !!(EmailValidator.email_regex =~ val)
  end

  def self.error_message(val)
    I18n.t('site_settings.errors.invalid_email')
  end
end
