# frozen_string_literal: true

class ThemeSettingsTagResolver
  def self.resolve(settings_by_theme:, guardian:)
    selections = []
    resolved =
      settings_by_theme.transform_values do |settings|
        settings = settings.dup
        (settings["theme_setting_type_info"] || {}).each do |name, info|
          next if info[:type] != "objects" || !includes_tag_objects?(info[:schema])

          settings[name] = settings[name].deep_dup
          each_object(settings[name], info[:schema]) do |object, schema|
            selections << [object, tag_names(object, schema)]
          end
        end
        settings
      end

    names = selections.flat_map(&:last).uniq
    ids_by_name = {}
    if names.present?
      ids_by_name =
        DiscourseTagging
          .filter_visible(Tag, guardian)
          .where_name(names)
          .pluck(:name, :id)
          .to_h { |name, id| [name.downcase, id] }
    end

    selections.each do |object, selected_names|
      object.delete(:tag_objects)
      object["tag_objects"] = selected_names.filter_map do |name|
        id = ids_by_name[name.downcase]
        { "id" => id, "name" => name } if id
      end
    end
    resolved
  end

  def self.remove_tag_objects(objects:, schema:)
    return objects if !includes_tag_objects?(schema)

    objects.deep_dup.tap do |copy|
      each_object(copy, schema) do |object, _|
        object.delete("tag_objects")
        object.delete(:tag_objects)
      end
    end
  end

  def self.includes_tag_objects?(schema)
    return false if schema.blank?
    return true if generates_tag_objects?(schema)

    schema[:properties].any? do |_, property|
      property[:type] == "objects" && includes_tag_objects?(property[:schema])
    end
  end

  def self.generates_tag_objects?(schema)
    properties = schema[:properties] || {}
    properties.keys.none? { |name| name.to_s == "tag_objects" } &&
      properties.values.any? { |property| property[:type] == "tags" }
  end

  def self.each_object(objects, schema, &block)
    return if !objects.is_a?(Array)

    objects.each do |object|
      next if !object.is_a?(Hash)

      yield object, schema if generates_tag_objects?(schema)
      schema[:properties].each do |name, property|
        if property[:type] == "objects" && includes_tag_objects?(property[:schema])
          each_object(object[object_key(object, name)], property[:schema], &block)
        end
      end
    end
  end

  def self.tag_names(object, schema)
    schema[:properties]
      .flat_map do |name, property|
        property[:type] == "tags" ? Array(object[object_key(object, name)]) : []
      end
      .grep(String)
  end

  def self.object_key(object, name)
    object.key?(name.to_s) ? name.to_s : name.to_sym
  end
  private_class_method :includes_tag_objects?,
                       :generates_tag_objects?,
                       :each_object,
                       :tag_names,
                       :object_key
end
