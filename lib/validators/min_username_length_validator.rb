class MinUsernameLengthValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    return false if value > SiteSetting.max_username_length
    @username = User.where('length(username) < ?', value).pluck(:username).first
    @username.blank?
  end

  def error_message
    if @username.blank?
      I18n.t("site_settings.errors.min_username_length_range")
    else
      I18n.t("site_settings.errors.min_username_length_exists", username: @username)
    end
  end
end
