# frozen_string_literal: true

class EnableDiscourseIdValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"
    return false if credentials_missing?
    true
  end

  def error_message
    I18n.t("site_settings.errors.discourse_id_credentials") if credentials_missing?
  end

  private

  def credentials_missing?
    SiteSetting.discourse_id_client_id.blank? || SiteSetting.discourse_id_client_secret.blank?
  end
end
