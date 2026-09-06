# frozen_string_literal: true

class ThemeSettingsGroupResolver
  # Resolves opted-in `type: groups` properties inside object settings while
  # leaving stored/admin values untouched.
  #
  # c.f. ThemeSettingsGroupResolver.resolve
  #
  # Example:
  #   input: { menu_sections: [{ "groups" => [1, 2], "name" => "Main" }] }
  #   output: { menu_sections: [{ "user_in_groups" => true, "name" => "Main" }] }
  class ObjectSetting
    def self.applies?(setting_info)
      setting_info[:type] == "objects"
    end

    def initialize(setting_name:, setting_info:, guardian:)
      @setting_name = setting_name
      @schema = setting_info[:schema]
      @guardian = guardian
    end

    def resolve!(settings)
      objects = settings[@setting_name]
      return if !objects.is_a?(Array) || !resolves_groups?(@schema)

      settings[@setting_name] = objects.deep_dup.each { |object| resolve_object!(object, @schema) }
    end

    private

    def resolves_groups?(schema)
      return false if schema.blank?

      schema[:properties].any? do |_, property|
        (property[:type] == "groups" && property[:resolve_group_membership]) ||
          (property[:type] == "objects" && resolves_groups?(property[:schema]))
      end
    end

    def resolve_object!(object, schema)
      schema[:properties].each do |property_name, property|
        if property[:type] == "groups" && property[:resolve_group_membership]
          resolve_group_property!(object, property_name)
        elsif property[:type] == "objects"
          resolve_nested_objects!(object, property_name, property[:schema])
        end
      end
    end

    def resolve_group_property!(object, property_name)
      key = object_key(object, property_name)
      group_ids = Array(object.delete(key)).map(&:to_i)
      object[resolved_key(key, property_name)] = @guardian.in_any_groups?(group_ids)
    end

    def resolve_nested_objects!(object, property_name, schema)
      nested_objects = object[object_key(object, property_name)]
      return if !nested_objects.is_a?(Array)

      nested_objects.each { |nested_object| resolve_object!(nested_object, schema) }
    end

    def object_key(object, property_name)
      string_key = property_name.to_s
      return string_key if object.key?(string_key)

      property_name.to_sym
    end

    def resolved_key(original_key, property_name)
      original_key.is_a?(String) ? "user_in_#{property_name}" : :"user_in_#{property_name}"
    end
  end
end
