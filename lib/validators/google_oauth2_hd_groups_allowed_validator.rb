# frozen_string_literal: true

class GoogleOauth2HdGroupsAllowedValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    @valid =
      value.blank? ||
        (
          SiteSetting.google_oauth2_hd.present? &&
            SiteSetting.google_oauth2_hd_groups_service_account_admin_email.present? &&
            SiteSetting.google_oauth2_hd_groups_service_account_json.present?
        )
  end

  def error_message
    I18n.t("site_settings.errors.google_oauth2_hd_groups_allowed") if !@valid
  end
end
