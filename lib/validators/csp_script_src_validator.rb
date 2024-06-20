# frozen_string_literal: true

class CspScriptSrcValidator
  def initialize(opts = {})
    @opts = opts
  end

  def valid_value?(values)
    return true if values == ""

    regex =
      /
        (?:\A'unsafe-eval'\z)|
        (?:\A'wasm-unsafe-eval'\z)|
        (?:\A'sha(?:256|384|512)-[A-Za-z0-9+\/\-_]+={0,2}'\z)
      /x

    values.split("|").all? { |v| v.match? regex }
  end

  def error_message
    I18n.t("site_settings.errors.invalid_csp_script_src")
  end
end
