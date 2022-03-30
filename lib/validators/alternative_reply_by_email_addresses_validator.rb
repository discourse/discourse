# frozen_string_literal: true

class AlternativeReplyByEmailAddressesValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val.blank?

    validator = ReplyByEmailAddressValidator.new(@opts)
    val.split("|").all? { |v| validator.valid_value?(v) }
  end

  def error_message
    I18n.t('site_settings.errors.invalid_alternative_reply_by_email_addresses')
  end
end
