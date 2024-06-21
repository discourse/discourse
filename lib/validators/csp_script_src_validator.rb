# frozen_string_literal: true

class CspScriptSrcValidator
  VALID_SOURCE_REGEX =
    /
        (?:\A'unsafe-eval'\z)|
        (?:\A'wasm-unsafe-eval'\z)|
        (?:\A'sha(?:256|384|512)-[A-Za-z0-9+\/\-_]+={0,2}'\z)
      /x

  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(values)
    values.split("|").all? { _1.match? VALID_SOURCE_REGEX }
  end

  def error_message
    I18n.t("site_settings.errors.invalid_csp_script_src")
  end
end
