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

class ChildThemeSerializer < ApplicationSerializer
  attributes :id, :name, :created_at, :updated_at, :default, :component

  def include_default?
    object.id == SiteSetting.default_theme_id
  end

  def default
    true
  end
end

class RemoteThemeSerializer < ApplicationSerializer
  attributes :id, :remote_url, :remote_version, :local_version, :about_url,
             :license_url, :commits_behind, :remote_updated_at, :updated_at,
             :github_diff_link, :last_error_text

  # wow, AMS has some pretty nutty logic where it tries to find the path here
  # from action dispatch, tell it not to
  def about_url
    object.about_url
  end

  def include_github_diff_link?
    github_diff_link.present?
  end
end

class ThemeSerializer < ChildThemeSerializer
  attributes :color_scheme, :color_scheme_id, :user_selectable, :remote_theme_id, :settings, :errors

  has_one :user, serializer: UserNameSerializer, embed: :object

  has_many :theme_fields, serializer: ThemeFieldSerializer, embed: :objects
  has_many :child_themes, serializer: ChildThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects
  has_many :translations, serializer: ThemeTranslationSerializer, embed: :objects

  def initialize(theme, options = {})
    super
    @errors = []
  end

  def child_themes
    object.child_themes
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
end

class ThemeFieldWithEmbeddedUploadsSerializer < ThemeFieldSerializer
  attributes :raw_upload

  def include_raw_upload?
    object.upload
  end

  def raw_upload
    filename = Discourse.store.path_for(object.upload)
    raw = nil

    if filename
      raw = File.read(filename)
    else
      raw = Discourse.store.download(object.upload).read
    end

    Base64.encode64(raw)
  end
end

class ThemeWithEmbeddedUploadsSerializer < ThemeSerializer
  has_many :theme_fields, serializer: ThemeFieldWithEmbeddedUploadsSerializer, embed: :objects

  def include_settings?
    false
  end
end
