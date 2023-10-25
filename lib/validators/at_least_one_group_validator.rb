# frozen_string_literal: true

class AtLeastOneGroupValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.present? && val != ""
  end

  def error_message
    I18n.t("site_settings.errors.at_least_one_group_required")
  end
end
