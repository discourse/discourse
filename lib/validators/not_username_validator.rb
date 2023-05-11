# frozen_string_literal: true

class NotUsernameValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    val.blank? || !User.where(username: val).exists?
  end

  def error_message
    I18n.t("site_settings.errors.valid_username")
  end
end
