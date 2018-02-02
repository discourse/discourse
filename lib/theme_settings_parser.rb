class ThemeSettingsParser
  class InvalidYaml < StandardError; end

  def initialize(setting_field)
    @setting_field = setting_field
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
      yield(setting, nil, nil, {}) if value.nil?

      if (type = ThemeSetting.guess_type(value)).present?
        yield setting, value, type, {}
      elsif (hash = value).is_a?(Hash)
        default = hash[:default]
        type = hash.key?(:type) ? ThemeSetting.types[hash[:type]&.to_sym] : ThemeSetting.guess_type(default)

        opts = {}
        opts[:description] = extract_description(hash[:description])

        if type == ThemeSetting.types[:enum]
          choices = hash[:choices]
          choices = [] unless choices.is_a?(Array)
          choices << default unless choices.include?(default)
          opts[:choices] = choices
        end

        yield setting, default, type, opts
      else
        yield setting, value, nil, {}
      end
    end
  end
end
