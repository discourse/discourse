# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def value
    has_record? ? db_record.json_value : default.map!(&:deep_stringify_keys)
  end

  def value=(objects)
    # TODO: Validate the objects against the schema

    record = has_record? ? db_record : create_record!
    record.json_value = objects
    record.save!
    theme.reload
    record.json_value
  end
end
