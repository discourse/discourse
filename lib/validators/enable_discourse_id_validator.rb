# frozen_string_literal: true

class EnableDiscourseIdValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(val)
    return true if val == "f"

    if credentials_missing?
      @result = DiscourseId::Register.call
      return @result.success?
    end

    true
  end

  def error_message
    if @result&.error.present?
      @result.error
    elsif credentials_missing?
      I18n.t("site_settings.errors.discourse_id_credentials")
    end
  end

  private

  def credentials_missing?
    SiteSetting.discourse_id_client_id.blank? || SiteSetting.discourse_id_client_secret.blank?
  end
end
