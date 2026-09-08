# frozen_string_literal: true

class ThemeSettingsParser
  class InvalidYaml < StandardError
  end

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

  def create_opts(default, type, raw_opts = {}, name: nil)
    opts = {}
    opts[:description] = extract_description(raw_opts[:description])

    if type == @types[:enum]
      choices = raw_opts[:choices]
      choices = [] unless choices.is_a?(Array)
      choices << default if choices.exclude?(default)
      opts[:choices] = choices
    end

    if [@types[:integer], @types[:string], @types[:float]].include?(type)
      opts[:max] = raw_opts[:max].is_a?(Numeric) ? raw_opts[:max] : Float::INFINITY
      opts[:min] = raw_opts[:min].is_a?(Numeric) ? raw_opts[:min] : -Float::INFINITY
    end

    opts[:list_type] = raw_opts[:list_type] if raw_opts[:list_type]
    if type == @types[:list] && raw_opts[:list_type] == "group"
      compile_group_list_constraints!(opts, raw_opts, name:)
    end
    opts[:resolve_group_membership] = !!raw_opts[:resolve_group_membership]

    opts[:textarea] = !!raw_opts[:textarea]
    opts[:json_schema] = raw_opts[:json_schema]
    opts[:schema] = raw_opts[:schema]
    if type == @types[:objects]
      object_group_list_constraints = {}
      compile_object_group_list_constraints!(opts[:schema], object_group_list_constraints, name:)
      if object_group_list_constraints.present?
        opts[:object_group_list_constraints] = object_group_list_constraints
      end
    end

    opts[:refresh] = !!raw_opts[:refresh]

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
        result = [setting, value, type, create_opts(value, type, name: setting)]
      elsif (hash = value).is_a?(Hash)
        default = hash[:default]
        type = hash.key?(:type) ? @types[hash[:type]&.to_sym] : ThemeSetting.guess_type(default)

        opts = create_opts(default, type, hash, name: setting)
        default = resolve_group_list_default!(setting, default, opts) if group_list?(type, opts)
        result = [setting, default, type, opts]
      else
        result = [setting, value, nil, {}]
      end

      yield(*result)
    end
  end

  private

  # Theme yaml is authored by an admin at runtime, so a rule they got wrong is
  # reported to them in their own locale rather than as a developer message.
  def raise_schema_error!(name, errors)
    raise InvalidYaml,
          I18n.t(
            "themes.settings_errors.group_constraints_not_valid",
            name: name,
            error_messages: errors.join(" "),
          )
  end

  def raise_at_least_one_error!(property)
    raise InvalidYaml,
          I18n.t("themes.settings_errors.group_at_least_one_not_supported", property: property)
  end

  def group_list?(type, opts)
    type == @types[:list] && opts[:list_type] == "group"
  end

  def compile_group_list_constraints!(opts, raw_opts, name:)
    opts.merge!(raw_opts.slice(:constraints, :mandatory_values, :disallowed_groups, :validator))
    constraints, errors =
      SiteSettings::GroupListConstraints.from_opts!(opts, name:, group_type: true)
    raise_schema_error!(name, errors) if errors.present?

    opts[:constraints] = constraints
    opts[:mandatory_values] = constraints.mandatory_values if constraints.mandatory_values
    opts[:disallowed_groups] = constraints.disallowed_groups if constraints.disallowed_groups
  end

  def resolve_group_list_default!(name, default, opts)
    resolved = SiteSettings::GroupRefs.resolve_list(default, context: "#{name} default")
    opts[:constraints].validate_default!(resolved, name:)
  rescue SiteSettings::GroupListConstraints::SchemaError,
         SiteSettings::GroupRefs::SchemaError => error
    raise_schema_error!(name, [error.message])
  end

  def compile_object_group_list_constraints!(schema, object_group_list_constraints, name:, path: [])
    return if schema.blank?

    schema[:properties].each do |property_name, property|
      property_path = path + [property_name]
      context = "#{name} schema property #{property_path.join(".")}"

      case property[:type]
      when "groups"
        if property[:constraints].is_a?(Hash) && property[:constraints].key?(:at_least_one)
          raise_at_least_one_error!(context)
        end

        constraints, errors =
          SiteSettings::GroupListConstraints.from_opts!(property, name: context, group_type: true)
        raise_schema_error!(name, errors) if errors.present?
        raise_at_least_one_error!(context) if constraints.at_least_one

        object_group_list_constraints[property_path] = constraints
        property[:mandatory_values] = constraints.mandatory_values if constraints.mandatory_values
        if constraints.disallowed_groups
          property[:disallowed_groups] = constraints.disallowed_groups
        end
      when "objects"
        compile_object_group_list_constraints!(
          property[:schema],
          object_group_list_constraints,
          name:,
          path: property_path,
        )
      end
    end
  end
end
