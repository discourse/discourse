# frozen_string_literal: true

class UnicodeUsernameAllowlistValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(value)
    @error_message = nil
    return true if value.blank?

    if value.match?(%r{\A/.*/[imxo]*\z})
      @error_message =
        I18n.t("site_settings.errors.allowed_unicode_usernames.leading_trailing_slash")
    else
      begin
        Regexp.new(value)
      rescue RegexpError => e
        @error_message =
          I18n.t("site_settings.errors.allowed_unicode_usernames.regex_invalid", error: e.message)
      end
    end

    @error_message.blank?
  end

  def error_message
    @error_message
  end
end
