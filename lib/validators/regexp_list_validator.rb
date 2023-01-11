# frozen_string_literal: true

class RegexpListValidator
  def initialize(opts = {})
  end

  def valid_value?(value)
    value
      .split("|")
      .all? do |regexp|
        begin
          Regexp.new(regexp)
        rescue RegexpError => e
          @regexp = regexp
          @error_message = e.message
          false
        end
      end
  end

  def error_message
    I18n.t(
      "site_settings.errors.invalid_regex_with_message",
      regex: @regexp,
      message: @error_message,
    )
  end
end
