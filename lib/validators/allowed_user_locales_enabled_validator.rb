# frozen_string_literal: true

class AllowedUserLocalesEnabledValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    # only validate when enabling setting locale from headers
    return true if val == "f"
    SiteSetting.allowed_user_locales.present?
  end

  def error_message
    I18n.t("site_settings.errors.user_locale_not_enabled")
  end
end
