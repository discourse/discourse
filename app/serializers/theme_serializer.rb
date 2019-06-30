# frozen_string_literal: true

require 'base64'

class ThemeFieldSerializer < ApplicationSerializer
  attributes :name, :target, :value, :error, :type_id, :upload_id, :url, :filename

  def include_url?
    object.upload
  end

  def include_upload_id?
    object.upload
  end

  def include_filename?
    object.upload
  end

  def url
    object.upload&.url
  end

  def filename
    object.upload&.original_filename
  end

  def target
    Theme.lookup_target(object.target_id)&.to_s
  end

  def include_error?
    object.error.present?
  end
end

class BasicThemeSerializer < ApplicationSerializer
  attributes :id, :name, :created_at, :updated_at, :default, :component

  def include_default?
    object.id == SiteSetting.default_theme_id
  end

  def default
    true
  end
end

class RemoteThemeSerializer < ApplicationSerializer
  attributes :id, :remote_url, :remote_version, :local_version, :commits_behind,
             :remote_updated_at, :updated_at, :github_diff_link, :last_error_text, :is_git?,
             :license_url, :about_url, :authors, :theme_version, :minimum_discourse_version, :maximum_discourse_version

  # wow, AMS has some pretty nutty logic where it tries to find the path here
  # from action dispatch, tell it not to
  def about_url
    object.about_url
  end

  def include_github_diff_link?
    github_diff_link.present?
  end
end

class ThemeSerializer < BasicThemeSerializer
  attributes :color_scheme, :color_scheme_id, :user_selectable, :remote_theme_id,
             :settings, :errors, :supported?, :description, :enabled?, :disabled_at

  has_one :user, serializer: UserNameSerializer, embed: :object
  has_one :disabled_by, serializer: UserNameSerializer, embed: :object

  has_many :theme_fields, serializer: ThemeFieldSerializer, embed: :objects
  has_many :child_themes, serializer: BasicThemeSerializer, embed: :objects
  has_many :parent_themes, serializer: BasicThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects
  has_many :translations, serializer: ThemeTranslationSerializer, embed: :objects

  def initialize(theme, options = {})
    super
    @errors = []
  end

  def child_themes
    object.child_themes
  end

  def parent_themes
    object.parent_themes
  end

  def settings
    object.settings.map { |setting| ThemeSettingsSerializer.new(setting, root: false) }
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
    object.internal_translations.find  { |t| t.key == "theme_metadata.description" } &.value
  end

  def include_disabled_at?
    object.component? && !object.enabled?
  end

  def include_disabled_by?
    include_disabled_at?
  end
end
