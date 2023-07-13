# frozen_string_literal: true

class MinUsernameLengthValidator
  MIN_USERNAME_LENGTH_RANGE = 1..60

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    if !MIN_USERNAME_LENGTH_RANGE.cover?(value)
      @min_range_violation = true
      return false
    end
    return false if value > SiteSetting.max_username_length
    @username = User.where("length(username) < ?", value).pick(:username)
    @username.blank?
  end

  def error_message
    if @min_length_violation
      I18n.t(
        "site_settings.errors.invalid_integer_min_max",
        min: MIN_USERNAME_LENGTH_RANGE.begin,
        max: MIN_USERNAME_LENGTH_RANGE.end,
      )
    elsif @username.blank?
      I18n.t("site_settings.errors.min_username_length_range")
    else
      I18n.t("site_settings.errors.min_username_length_exists", username: @username)
    end
  end
end
