class MaxUsernameLengthValidator

  def initialize(opts = {})
    @opts = opts
    @username = ""
  end

  def valid_value?(val)
    return false if val < SiteSetting.min_username_length

    users = User.where('length(username) > ?', val).limit(1)
    return true if users.size == 0

    @username = users[0].username
    false
  end

  def error_message
    if @username == ""
      I18n.t("site_settings.errors.max_username_length_range")
    else
      I18n.t("site_settings.errors.max_username_length_exists", username: @username)
    end
  end
end
