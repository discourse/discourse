# frozen_string_literal: true

class MaxUsernameLengthValidator
  MAX_USERNAME_LENGTH_RANGE = 8..60

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    if !MAX_USERNAME_LENGTH_RANGE.cover?(value)
      @max_range_violation = true
      return false
    end

    if value < SiteSetting.min_username_length
      @min_value_violation = true
      return false
    end

    @username = User.where("length(username) > ?", value).pick(:username)
    @group_name = Group.where(automatic: false).where("length(name) > ?", value).pick(:name)

    @username.blank? && @group_name.blank?
  end

  def error_message
    if @max_range_violation
      I18n.t(
        "site_settings.errors.invalid_integer_min_max",
        min: MAX_USERNAME_LENGTH_RANGE.begin,
        max: MAX_USERNAME_LENGTH_RANGE.end,
      )
    elsif @min_value_violation
      I18n.t("site_settings.errors.max_username_length_range")
    elsif @username.present?
      I18n.t("site_settings.errors.max_username_length_exists", username: @username)
    elsif @group_name.present?
      I18n.t("site_settings.errors.max_group_name_length_exists", group_name: @group_name)
    end
  end
end
