# frozen_string_literal: true

class RegexPresenceValidator
  include RegexSettingValidation

  def initialize(opts = {})
    @opts = opts
    initialize_regex_opts(opts)
  end

  def valid_value?(val)
    val.present? && regex_match?(val)
  end

  def error_message
    I18n.t(@regex_error)
  end
end
