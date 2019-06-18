# frozen_string_literal: true

class ThemeSettingsParser
  class InvalidYaml < StandardError; end

  def initialize(setting_field)
    @setting_field = setting_field
    @types = ThemeSetting.types
  end

  def extract_description(desc)
    return desc if desc.is_a?(String)

    if desc.is_a?(Hash)
      default_locale = SiteSetting.default_locale.to_sym
      fallback_locale = desc.keys.find { |key| I18n.locale_available?(key) }
      locale = desc[I18n.locale] || desc[default_locale] || desc[:en] || desc[fallback_locale]

      locale if locale.is_a?(String)
    end
  end

  def create_opts(default, type, raw_opts = {})
    opts = {}
    opts[:description] = extract_description(raw_opts[:description])

    if type == @types[:enum]
      choices = raw_opts[:choices]
      choices = [] unless choices.is_a?(Array)
      choices << default unless choices.include?(default)
      opts[:choices] = choices
    end

    if [@types[:integer], @types[:string], @types[:float]].include?(type)
      opts[:max] = raw_opts[:max].is_a?(Numeric) ? raw_opts[:max] : Float::INFINITY
      opts[:min] = raw_opts[:min].is_a?(Numeric) ? raw_opts[:min] : -Float::INFINITY
    end

    if raw_opts[:list_type]
      opts[:list_type] = raw_opts[:list_type]
    end

    opts[:textarea] = !!raw_opts[:textarea]

    opts
  end

  def load
    return if @setting_field.value.blank?

    begin
      parsed = YAML.safe_load(@setting_field.value)
    rescue Psych::SyntaxError, Psych::DisallowedClass => e
      raise InvalidYaml.new(e.message)
    end
    raise InvalidYaml.new(I18n.t("themes.settings_errors.invalid_yaml")) unless parsed.is_a?(Hash)

    parsed.deep_symbolize_keys!

    parsed.each_pair do |setting, value|
      if (type = ThemeSetting.guess_type(value)).present?
        result = [setting, value, type, create_opts(value, type)]
      elsif (hash = value).is_a?(Hash)
        default = hash[:default]
        type = hash.key?(:type) ? @types[hash[:type]&.to_sym] : ThemeSetting.guess_type(default)

        result = [setting, default, type, create_opts(default, type, hash)]
      else
        result = [setting, value, nil, {}]
      end

      yield(*result)
    end
  end
end
