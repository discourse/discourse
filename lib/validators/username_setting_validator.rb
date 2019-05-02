# frozen_string_literal: true

class UsernameSettingValidator

  include RegexSettingValidation

  def initialize(opts = {})
    @opts = opts
    initialize_regex_opts(opts)
  end

  def valid_value?(val)
    !val.present? || (User.where(username: val).exists? && regex_match?(val))
  end

  def error_message
    if @regex_fail
      I18n.t(@regex_error)
    else
      I18n.t('site_settings.errors.invalid_username')
    end
  end
end
