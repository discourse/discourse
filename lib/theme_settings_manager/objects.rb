# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def self.extract_value_from_row(row)
    row.json_value
  end

  def default
    hydrate_uploads(remove_tag_objects(@default.map(&:deep_stringify_keys)))
  end

  def value
    has_record? ? hydrate_uploads(remove_tag_objects(db_record.json_value)) : default
  end

  def value=(objects)
    objects = JSON.parse(objects) if objects.is_a?(::String)
    objects = remove_disallowed_groups(objects)
    objects = remove_tag_objects(objects)
    objects = normalize_tag_ids(objects)
    ensure_is_valid_value!(objects)
    objects = SchemaSettingsObjectValidator.normalize_uploads(schema:, objects:)
    # preserve pending changes on the caller's theme.
    Theme
      .find(theme.id)
      .with_lock do
        theme.association(:theme_settings).reset
        previous_defaults =
          if translations?
            begin
              theme.object_translation_defaults(reload: true)
            rescue Discourse::InvalidParameters
              nil
            end
          end
        record =
          has_record? ? update_record!(json_value: objects) : create_record!(json_value: objects)
        if translations?
          current_defaults = theme.object_translation_defaults(reload: true)
          theme.refresh_object_translations!(invalidate: previous_defaults != current_defaults)
        else
          theme.association(:theme_settings).reset
        end
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
    ThemeObjectTranslations.collect(schema:, objects: value, name:)
  end

  private

  def remove_tag_objects(objects)
    ThemeSettingsTagResolver.remove_tag_objects(objects:, schema:)
  end

  def normalize_tag_ids(objects, properties: schema[:properties], tag_names: nil)
    unless tag_names
      tag_ids =
        SchemaSettingsObjectValidator.property_values_of_type(schema:, objects:, type: "tags").grep(
          ::Integer,
        )
      return objects if tag_ids.empty?

      tag_names = Tag.where(id: tag_ids).pluck(:id, :name).to_h
    end

    objects.each do |object|
      properties.each do |property_name, property_attributes|
        key = object_key(object, property_name)
        next if key.nil?

        value = object[key]
        case property_attributes[:type]
        when "tags"
          if value.is_a?(Array)
            object[key] = value.map { |tag| tag.is_a?(::Integer) ? tag_names.fetch(tag, tag) : tag }
          end
        when "objects"
          if value.is_a?(Array)
            normalize_tag_ids(
              value,
              properties: property_attributes[:schema][:properties],
              tag_names:,
            )
          end
        end
      end
    end

    objects
  end

  def remove_disallowed_groups_from_objects(objects, properties)
    unless ThemeSettingsValidator.is_valid_value_type?(objects, type)
      raise Discourse::InvalidParameters, I18n.t("themes.settings_errors.objects.invalid_objects")
    end

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
          if !nested_objects.nil?
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
