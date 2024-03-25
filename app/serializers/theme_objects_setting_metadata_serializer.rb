# frozen_string_literal: true

class ThemeObjectsSettingMetadataSerializer < ApplicationSerializer
  attributes :property_descriptions

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
