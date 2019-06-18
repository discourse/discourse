# frozen_string_literal: true

class ColorListValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    hex_regex = /\A\h{6}\z/
    value.split("|").all? { |c| c =~ hex_regex }
  end

  def error_message
    I18n.t('site_settings.errors.invalid_hex_value')
  end
end
