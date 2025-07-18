# frozen_string_literal: true

class Oauth2FetchUserDetailsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "t"
    SiteSetting.oauth2_callback_user_id_path.length > 0
  end

  def error_message
    I18n.t("site_settings.errors.oauth2_fetch_user_details")
  end
end
