# frozen_string_literal: true

class StringSettingValidator
  include RegexSettingValidation

  def initialize(opts = {})
    @opts = opts
    initialize_regex_opts(opts)
  end

  def valid_value?(val)
    return true if !val.present?

    if (@opts[:min] && @opts[:min].to_i > (val.length)) ||
         (@opts[:max] && @opts[:max].to_i < (val.length))
      @length_fail = true
      return false
    end

    return valid_json?(val) if (@opts[:json_schema])

    regex_match?(val)
  end

  def valid_json?(json)
    # TODO: right now this is only ensuring JSON is valid
    # but ideally we should validate against the schema
    begin
      JSON.parse(json)
    rescue JSON::ParserError => e
      @json_fail = true
      return false
    end
    true
  end

  def error_message
    if @regex_fail
      I18n.t(@regex_error)
    elsif @length_fail
      if @opts[:min] && @opts[:max]
        I18n.t("site_settings.errors.invalid_string_min_max", min: @opts[:min], max: @opts[:max])
      elsif @opts[:min]
        I18n.t("site_settings.errors.invalid_string_min", min: @opts[:min])
      else
        I18n.t("site_settings.errors.invalid_string_max", max: @opts[:max])
      end
    elsif @json_fail
      I18n.t("site_settings.errors.invalid_json")
    else
      I18n.t("site_settings.errors.invalid_string")
    end
  end
end
