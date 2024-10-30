# frozen_string_literal: true

require "base64"

class ThemeSerializer < BasicThemeSerializer
  attributes :color_scheme_id,
             :user_selectable,
             :auto_update,
             :remote_theme_id,
             :settings,
             :errors,
             :supported?,
             :description,
             :enabled?,
             :disabled_at,
             :theme_fields,
             :screenshot_url

  has_one :color_scheme, serializer: ColorSchemeSerializer, embed: :object
  has_one :user, serializer: UserNameSerializer, embed: :object
  has_one :disabled_by, serializer: UserNameSerializer, embed: :object

  has_many :child_themes, serializer: BasicThemeSerializer, embed: :objects
  has_many :parent_themes, serializer: BasicThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects
  has_many :translations, serializer: ThemeTranslationSerializer, embed: :objects

  def initialize(theme, options = {})
    super
    @include_theme_field_values = options[:include_theme_field_values] || false
    @errors = []

    object.theme_fields.each { |o| @errors << o.error if o.error }
  end

  def theme_fields
    ActiveModel::ArraySerializer.new(
      object.theme_fields,
      each_serializer: ThemeFieldSerializer,
      include_value: include_theme_field_values?,
    ).as_json
  end

  def include_theme_field_values?
    # This is passed into each `ThemeFieldSerializer` to determine if `value` will be serialized.
    # We only want to serialize if we are viewing staff_action_logs (for diffing changes), or if
    # the theme is a local theme, so the saved values appear in the theme field editor.
    @include_theme_field_values || object.remote_theme_id.nil?
  end

  def screenshot_url
    object
      .theme_fields
      .find { |field| field.type_id == ThemeField.types[:theme_screenshot_upload_var] }
      &.upload_url
  end

  def child_themes
    object.child_themes
  end

  def parent_themes
    object.parent_themes
  end

  def settings
    object.settings.map do |_name, setting|
      ThemeSettingsSerializer.new(setting, scope:, root: false)
    end
  rescue ThemeSettingsParser::InvalidYaml => e
    @errors << e.message
    nil
  end

  def include_child_themes?
    !object.component?
  end

  def errors
    @errors
  end

  def include_errors?
    @errors.present?
  end

  def description
    object.internal_translations.find { |t| t.key == "theme_metadata.description" }&.value
  end

  def include_disabled_at?
    object.component? && !object.enabled?
  end

  def include_disabled_by?
    include_disabled_at?
  end
end
