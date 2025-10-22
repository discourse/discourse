# frozen_string_literal: true

class AssignStatusesValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    statuses = value.split("|")

    case
    when statuses.size < 2
      @reason = "too_few"
      return false
    when statuses.size != statuses.uniq.size
      @reason = "duplicate"
      return false
    when Assignment.where.not(status: statuses).count > 0
      @reason = "removed_in_use"
      return false
    end

    true
  end

  def error_message
    I18n.t("site_settings.errors.assign_statuses.#{@reason}")
  end
end
