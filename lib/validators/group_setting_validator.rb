# frozen_string_literal: true

class GroupSettingValidator

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.blank? || Group.exists?(name: val)
  end

  def error_message
    I18n.t('site_settings.errors.invalid_group')
  end
end
