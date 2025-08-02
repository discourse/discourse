# frozen_string_literal: true

class ReplyByEmailAddressValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?
    return false if !EmailAddressValidator.valid_value?(val)

    if SiteSetting.find_related_post_with_key
      return false if !val.include?("%{reply_key}")
      val.sub(/\+?%{reply_key}/, "") != SiteSetting.notification_email
    else
      val != SiteSetting.notification_email
    end
  end

  def error_message
    I18n.t("site_settings.errors.invalid_reply_by_email_address")
  end
end
