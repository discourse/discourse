# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def self.extract_value_from_row(row)
    row.json_value
  end

  def default
    hydrate_uploads(@default.map(&:deep_stringify_keys))
  end

  def value
    has_record? ? hydrate_uploads(db_record.json_value) : default
  end

  def value=(objects)
    objects = JSON.parse(objects) if objects.is_a?(::String)
    objects = remove_disallowed_groups(objects)
    ensure_is_valid_value!(objects)
    objects = SchemaSettingsObjectValidator.normalize_uploads(schema:, objects:)
    # Lock a separate instance to preserve pending changes on the caller's theme.
    Theme
      .find(theme.id)
      .with_lock do
        previous_keys = theme.object_translation_defaults(reload: true).keys
        record =
          has_record? ? update_record!(json_value: objects) : create_record!(json_value: objects)
        theme.object_translation_defaults(reload: true)
        theme.refresh_object_translations!(previous_keys: previous_keys)
        record.json_value
      end
  end

  def schema
    @opts[:schema]
  end

  def hydrate_uploads(objects)
    SchemaSettingsObjectValidator.hydrate_uploads(schema:, objects:, cdn: true)
  end

  def remove_disallowed_groups(objects)
    return objects if objects.blank?

    remove_disallowed_groups_from_objects(objects.deep_dup, schema[:properties])
  end

  def categories(guardian)
    category_ids = Set.new

    value.each do |theme_setting_object|
      category_ids.merge(
        SchemaSettingsObjectValidator.new(
          schema:,
          object: theme_setting_object,
        ).property_values_of_type("categories"),
      )
    end

    return [] if category_ids.empty?

    Category.secured(guardian).where(id: category_ids)
  end

  def translations?
    ThemeSettingsValidator.translatable_object_schema?(schema)
  end

  def translation_defaults
    return {} unless translations?
    metadata = schema[:translations] || {}
    invalid_translation_keys! unless metadata.is_a?(Hash)
    locale = metadata[:default_locale] || "en"
    invalid_translation_keys! unless LocaleSiteSetting.valid_value?(locale)
    entries = collect_translation_defaults(schema, value, name.to_s, locale, {})
    entries
      .keys
      .sort
      .each_cons(2) do |parent, child|
        if child.start_with?("#{parent}.")
          raise Discourse::InvalidParameters.new(
                  I18n.t("themes.settings_errors.nested_translation_key_conflict", key: parent),
                )
        end
      end
    entries
  end

  private

  def collect_translation_defaults(schema, objects, prefix, locale, entries)
    return entries unless ThemeSettingsValidator.translatable_object_schema?(schema)
    unless schema.dig(:properties, :translation_key, :type) == "string" &&
             schema.dig(:properties, :translation_key, :required) == true
      invalid_translation_keys!
    end
    fields =
      schema[:properties].filter_map do |field, spec|
        next unless spec[:translatable] == true
        unless /\A[a-z][a-z0-9_]*\z/.match?(field.to_s) && spec[:type] == "string"
          invalid_translation_keys!
        end
        field
      end
    seen = Set.new
    objects.each do |object|
      object = object.with_indifferent_access
      identifier = object[:translation_key].to_s
      unless identifier.length <= 80 && /\A[a-z][a-z0-9_]*\z/.match?(identifier) &&
               seen.add?(identifier)
        invalid_translation_keys!
      end
      object_prefix = "#{prefix}.#{identifier}"
      fields.each do |field|
        key = "#{object_prefix}.#{field}"
        invalid_translation_keys! if key.bytesize > 400 || entries.key?(key)
        entries[key] = { text: object[field].to_s, locale: locale }
      end
      schema[:properties].each do |property, spec|
        next unless spec[:type] == "objects"
        collect_translation_defaults(
          spec[:schema],
          object[property] || [],
          object_prefix,
          locale,
          entries,
        )
      end
    end
    entries
  end

  def invalid_translation_keys!
    raise Discourse::InvalidParameters.new(
            I18n.t("themes.settings_errors.invalid_translation_keys"),
          )
  end

  def remove_disallowed_groups_from_objects(objects, properties)
    objects.each do |object|
      properties.each do |property_name, property_attributes|
        key = object_key(object, property_name)
        next if key.nil?

        case property_attributes[:type]
        when "groups"
          next if property_attributes[:disallowed_groups].blank?

          disallowed_ids = property_attributes[:disallowed_groups].to_s.split("|").map(&:to_i)
          object[key] = Array(object[key]).reject { |id| disallowed_ids.include?(id) }
        when "objects"
          nested_objects = object[key]
          if nested_objects.is_a?(Array)
            remove_disallowed_groups_from_objects(
              nested_objects,
              property_attributes[:schema][:properties],
            )
          end
        end
      end
    end

    objects
  end

  def object_key(object, property_name)
    string_key = property_name.to_s
    return string_key if object.key?(string_key)

    symbol_key = property_name.to_sym
    symbol_key if object.key?(symbol_key)
  end
end
