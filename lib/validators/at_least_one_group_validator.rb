# frozen_string_literal: true

class AtLeastOneGroupValidator
  def initialize(opts = {})
    @opts = opts
    @invalid_groups = []
  end

  def valid_value?(val)
    @invalid_groups = []

    return false if val.blank?

    group_ids = val.to_s.split("|").map(&:to_i)

    @invalid_groups = group_ids - Group.where(id: group_ids).pluck(:id)
    @invalid_groups.empty?
  end

  def error_message
    if @invalid_groups.empty?
      I18n.t("site_settings.errors.at_least_one_group_required")
    else
      I18n.t("site_settings.errors.invalid_group")
    end
  end
end
