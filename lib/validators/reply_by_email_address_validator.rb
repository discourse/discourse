class ReplyByEmailAddressValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val&.strip!

    return true  if val.blank?
    return false if !val.include?("@")

    value = val.dup

    if SiteSetting.find_related_post_with_key
      return false if !value.include?("%{reply_key}")
      value.sub!(/\+?%{reply_key}/, "")
    end

    value != SiteSetting.notification_email && !value.include?(" ")
  end

  def error_message
    I18n.t('site_settings.errors.invalid_reply_by_email_address')
  end
end
