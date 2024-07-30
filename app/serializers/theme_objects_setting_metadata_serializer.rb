# frozen_string_literal: true

class ThemeObjectsSettingMetadataSerializer < ApplicationSerializer
  attributes :categories, :property_descriptions

  def categories
    object
      .categories(scope)
      .reduce({}) do |acc, category|
        acc[category.id] = BasicCategorySerializer.new(category, scope: scope, root: false).as_json
        acc
      end
  end

  def property_descriptions
    locales = {}
    key = "theme_metadata.settings.#{object.name}.schema.properties."

    object.theme.internal_translations.each do |internal_translation|
      if internal_translation.key.start_with?(key)
        locales[internal_translation.key.delete_prefix(key)] = internal_translation.value
      end
    end

    locales
  end
end
