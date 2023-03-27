# frozen_string_literal: true

class PersonalMessageEnabledGroupsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.present? && val != ""
  end

  def error_message
    I18n.t("site_settings.errors.personal_message_enabled_groups_invalid")
  end
end
