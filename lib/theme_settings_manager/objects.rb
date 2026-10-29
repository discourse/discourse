# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def self.extract_value_from_row(row)
    row.json_value
  end

  def default
    hydrate_uploads(@default.map(&:deep_stringify_keys))
  end

  def value
    objects = has_record? ? hydrate_uploads(db_record.json_value) : default
    remove_disallowed_groups(objects)
  end

  def value=(objects)
    objects = JSON.parse(objects) if objects.is_a?(::String)
    objects = remove_disallowed_groups(objects)
    ensure_is_valid_value!(objects)
    objects = SchemaSettingsObjectValidator.normalize_uploads(schema:, objects:)
    record = has_record? ? update_record!(json_value: objects) : create_record!(json_value: objects)
    theme.reload
    record.json_value
  end

  def schema
    @opts[:schema]
  end

  def hydrate_uploads(objects)
    SchemaSettingsObjectValidator.hydrate_uploads(schema:, objects:, cdn: true)
  end

  def remove_disallowed_groups(objects)
    return objects if objects.blank?

    remove_disallowed_groups_from_objects(objects.deep_dup, schema[:properties], path: [])
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

  private

  def remove_disallowed_groups_from_objects(objects, properties, path:)
    objects.each do |object|
      properties.each do |property_name, property_attributes|
        key = object_key(object, property_name)
        next if key.nil?

        property_path = path + [property_name]

        case property_attributes[:type]
        when "groups"
          constraints = @opts[:object_group_list_constraints]&.[](property_path)
          next if constraints.nil?
          object[key] = constraints.normalize_ids(Array(object[key]))
        when "objects"
          nested_objects = object[key]
          if nested_objects.is_a?(Array)
            remove_disallowed_groups_from_objects(
              nested_objects,
              property_attributes[:schema][:properties],
              path: property_path,
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
