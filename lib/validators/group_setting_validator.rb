# frozen_string_literal: true

class GroupSettingValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    group_id = Integer(val, exception: false)
    (group_id.present? && Group.exists?(id: group_id)) || Group.exists?(name: val)
  end

  def error_message
    I18n.t("site_settings.errors.invalid_group")
  end
end
