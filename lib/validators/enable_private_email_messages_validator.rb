class EnablePrivateEmailMessagesValidator

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    SiteSetting.enable_staged_users &&
    SiteSetting.reply_by_email_enabled
  end

  def error_message
    if !SiteSetting.enable_staged_users
      I18n.t("site_settings.errors.staged_users_disabled")
    elsif !SiteSetting.reply_by_email_enabled
      I18n.t("site_settings.errors.reply_by_email_disabled")
    end
  end
end
