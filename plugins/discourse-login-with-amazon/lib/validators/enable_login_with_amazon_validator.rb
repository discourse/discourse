# frozen_string_literal: true

class EnableLoginWithAmazonValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"

    if SiteSetting.login_with_amazon_client_id.blank? ||
         SiteSetting.login_with_amazon_client_secret.blank?
      return false
    end

    true
  end

  def error_message
    if SiteSetting.login_with_amazon_client_id.blank?
      I18n.t("site_settings.errors.login_with_amazon_client_id_is_blank")
    elsif SiteSetting.login_with_amazon_client_secret.blank?
      I18n.t("site_settings.errors.login_with_amazon_client_secret_is_blank")
    end
  end
end
