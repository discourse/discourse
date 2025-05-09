# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def self.extract_value_from_row(row)
    row.json_value
  end

  def value
    has_record? ? db_record.json_value : default.map!(&:deep_stringify_keys)
  end

  def value=(objects)
    objects = JSON.parse(objects) if objects.is_a?(::String)
    ensure_is_valid_value!(objects)
    record = has_record? ? update_record!(json_value: objects) : create_record!(json_value: objects)
    theme.reload
    record.json_value
  end

  def schema
    @opts[:schema]
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
end
