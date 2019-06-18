# frozen_string_literal: true

class ThemeTranslationParser
  INTERNAL_KEYS = [:theme_metadata]
  class InvalidYaml < StandardError; end

  def initialize(setting_field, internal: false)
    @setting_field = setting_field
    @internal = internal
  end

  def self.check_contains_hashes(hash)
    hash.all? { |key, value| value.is_a?(String) || (value.is_a?(Hash) && self.check_contains_hashes(value)) }
  end

  def load
    return {} if @setting_field.value.blank?

    begin
      parsed = YAML.safe_load(@setting_field.value)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
      raise InvalidYaml.new(e.message)
    end
    raise InvalidYaml.new(I18n.t("themes.locale_errors.invalid_yaml")) unless parsed.is_a?(Hash) && ThemeTranslationParser.check_contains_hashes(parsed)
    raise InvalidYaml.new(I18n.t("themes.locale_errors.top_level_locale")) unless parsed.keys.length == 1 && parsed.keys[0] == @setting_field.name

    parsed.deep_symbolize_keys!

    parsed[@setting_field.name.to_sym].slice!(*INTERNAL_KEYS) if @internal
    parsed[@setting_field.name.to_sym].except!(*INTERNAL_KEYS) if !@internal

    parsed
  end
end
