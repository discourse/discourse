# frozen_string_literal: true

class ThemeSettingsSerializer < ApplicationSerializer
  attributes :setting,
             :humanized_name,
             :type,
             :default,
             :value,
             :description,
             :valid_values,
             :list_type,
             :textarea,
             :json_schema,
             :objects_schema

  def setting
    object.name
  end

  def humanized_name
    SiteSetting.humanized_name(object.name)
  end

  def type
    object.type_name
  end

  def default
    object.default
  end

  def value
    object.value
  end

  def description
    description_regexp = /^theme_metadata\.settings\.#{setting}(\.description)?$/

    locale_file_description =
      object.theme.internal_translations.find { |t| t.key.match?(description_regexp) }&.value

    resolved_description = locale_file_description || object.description

    if resolved_description
      catch(:exception) do
        return I18n.interpolate(resolved_description, base_path: Discourse.base_path)
      end
      resolved_description
    end
  end

  def valid_values
    object.choices
  end

  def include_valid_values?
    object.type == ThemeSetting.types[:enum]
  end

  def include_description?
    description.present?
  end

  def list_type
    object.list_type
  end

  def include_list_type?
    object.type == ThemeSetting.types[:list]
  end

  def textarea
    object.textarea
  end

  def include_textarea?
    object.type == ThemeSetting.types[:string]
  end

  def objects_schema
    object.schema
  end

  def include_objects_schema?
    object.type == ThemeSetting.types[:objects]
  end

  def json_schema
    object.json_schema
  end

  def include_json_schema?
    object.type == ThemeSetting.types[:string] && object.json_schema.present?
  end
end
