class ReplyByEmailEnabledValidator

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    # only validate when enabling reply by email
    return true if val == "f"
    # ensure reply_by_email_address is configured && polling is working
    SiteSetting.reply_by_email_address.present? &&
    SiteSetting.email_polling_enabled?
  end

  def error_message
    if SiteSetting.reply_by_email_address.blank?
      I18n.t("site_settings.errors.reply_by_email_address_is_empty")
    else
      I18n.t("site_settings.errors.email_polling_disabled")
    end
  end

end
