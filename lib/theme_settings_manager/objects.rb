# frozen_string_literal: true

class ThemeSettingsManager::Objects < ThemeSettingsManager
  def self.extract_value_from_row(row)
    row.json_value
  end

  def value
    has_record? ? hydrated_objects : default.map!(&:deep_stringify_keys)
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

  # if it has uploads we can swap out ids for urls or cdn urls
  def hydrated_objects
    db_record.json_value.map { |theme_setting_object| hydrate(theme_setting_object) }
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

  def uploads
    upload_ids = Set.new

    value.each do |theme_setting_object|
      upload_ids.merge(
        SchemaSettingsObjectValidator.new(
          schema:,
          object: theme_setting_object,
        ).property_values_of_type("upload"),
      )
    end

    return [] if upload_ids.empty?

    ::Upload.where(id: upload_ids).to_a
  end

  def hydrate(theme_setting_object)
    theme_setting_object.each_with_object({}) do |(name, value), hydrated_object|
      property_schema = schema[:properties][name.to_sym]
      if property_schema && property_schema[:type] == "upload"
        upload = ::Upload.find_by_id(value.to_i)
        hydrated_object[name] = upload ? Discourse.store.cdn_url(upload.url) : nil
      else
        hydrated_object[name] = value
      end

      if property_schema && property_schema["type"] == "objects"
        hydrated_object[name] = value.map { |child_object| hydrate(child_object) }
      end
    end
  end
end
