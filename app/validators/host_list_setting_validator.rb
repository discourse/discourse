# frozen_string_literal: true

class HostListSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.exclude?("*") && val.exclude?("?")
  end

  def error_message
    I18n.t('site_settings.errors.invalid_domain_hostname')
  end
end
