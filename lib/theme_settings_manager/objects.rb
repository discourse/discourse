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

  private

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
