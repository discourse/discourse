# frozen_string_literal: true

class GroupSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    return false if !val.to_s.match?(/\A\d+\z/)

    Group.exists?(id: val)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_group")
  end
end
