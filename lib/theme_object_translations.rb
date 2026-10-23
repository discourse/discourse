# frozen_string_literal: true

class ThemeObjectTranslations
  IDENTIFIER = /\A[a-z][a-z0-9_]*\z/

  def self.collect(schema:, objects:, name:)
    return {} unless ThemeSettingsValidator.translatable_object_schema?(schema)
    new(schema, name).collect(objects)
  end

  def initialize(schema, name)
    @schema = schema
    @name = name.to_s
    @entries = {}
  end

  def collect(objects)
    metadata = @schema.fetch(:translations, {})
    invalid!(:metadata, path: @name) unless metadata.is_a?(Hash)
    locale = metadata.fetch(:default_locale, "en")
    unless locale.is_a?(String) && LocaleSiteSetting.supported_locales.include?(locale)
      invalid!(:locale, path: @name, value: locale.inspect)
    end
    collect_objects(@schema, objects, @name, locale)
    @entries
  end

  private

  def collect_objects(schema, objects, prefix, locale)
    return unless ThemeSettingsValidator.translatable_object_schema?(schema)
    seen = Set.new
    fields = schema[:properties].select { |_, spec| spec[:translatable] == true }
    objects.each_with_index do |object, index|
      object = object.with_indifferent_access
      identifier = object[:translation_key]
      path = "#{prefix}[#{index}].translation_key"
      unless identifier.is_a?(String) && identifier.length <= 80 && IDENTIFIER.match?(identifier)
        invalid!(:identifier, path:, value: identifier.inspect)
      end
      invalid!(:duplicate, path:, value: identifier) unless seen.add?(identifier)
      object_prefix = "#{prefix}.#{identifier}"
      fields.each_key do |field|
        key = "#{object_prefix}.#{field}"
        invalid!(:length, path: key) if key.bytesize > 400
        @entries[key] = { text: object[field].to_s, locale: }
      end
      schema[:properties].each do |property, spec|
        next unless spec[:type] == "objects"
        collect_objects(
          spec[:schema],
          object[property] || [],
          "#{object_prefix}.#{property}",
          locale,
        )
      end
    end
  end

  def invalid!(reason, **params)
    raise Discourse::InvalidParameters,
          I18n.t("themes.settings_errors.object_translation_#{reason}", **params)
  end
end
