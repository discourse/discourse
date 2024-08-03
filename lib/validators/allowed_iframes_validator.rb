# frozen_string_literal: true

class AllowedIframesValidator
  # Url starts with http:// or https:// and has at least one more additional '/'
  VALID_ALLOWED_IFRAME_URL_REGEX = %r{\Ahttps?://([^/]*/)+[^/]*\z}x

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(values)
    values.split("|").all? { _1.match? VALID_ALLOWED_IFRAME_URL_REGEX }
  end

  def error_message
    I18n.t("site_settings.errors.invalid_allowed_iframes_url")
  end
end
