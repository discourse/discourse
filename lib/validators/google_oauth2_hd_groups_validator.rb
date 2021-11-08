# frozen_string_literal: true

class GoogleOauth2HdGroupsValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    @valid = value == "f" || SiteSetting.google_oauth2_hd.present?
  end

  def error_message
    I18n.t("site_settings.errors.google_oauth2_hd_groups") if !@valid
  end
end
