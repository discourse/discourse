class ReplyByEmailAddressValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true  if val.blank?
    return false if val["@"].nil?

    if SiteSetting.find_related_post_with_key
      !!val["%{reply_key}"] && val.sub(/\+?%{reply_key}/, "") != SiteSetting.notification_email
    else
      val != SiteSetting.notification_email
    end
  end

  def error_message
    I18n.t('site_settings.errors.invalid_reply_by_email_address')
  end
end
