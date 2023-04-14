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
    return false if value < SiteSetting.min_username_length
    @username = User.where("length(username) > ?", value).pick(:username)
    @username.blank?
  end

  def error_message
    if @max_range_violation
      I18n.t(
        "site_settings.errors.invalid_integer_min_max",
        min: MAX_USERNAME_LENGTH_RANGE.begin,
        max: MAX_USERNAME_LENGTH_RANGE.end,
      )
    elsif @username.blank?
      I18n.t("site_settings.errors.max_username_length_range")
    else
      I18n.t("site_settings.errors.max_username_length_exists", username: @username)
    end
  end
end
