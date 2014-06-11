class UsernameSettingValidator
  def self.valid_value?(val)
    !val.present? || User.where(username: val).exists?
  end

  def self.error_message(val)
    I18n.t('site_settings.errors.invalid_username')
  end
end
