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
  attributes :id, :name, :key, :created_at, :updated_at, :default

  def include_default?
    object.key == SiteSetting.default_theme_key
  end

  def default
    true
  end
end

class RemoteThemeSerializer < ApplicationSerializer
  attributes :id, :remote_url, :remote_version, :local_version, :about_url,
             :license_url, :commits_behind, :remote_updated_at, :updated_at

  # wow, AMS has some pretty nutty logic where it tries to find the path here
  # from action dispatch, tell it not to
  def about_url
    object.about_url
  end
end

class ThemeSerializer < ChildThemeSerializer
  attributes :color_scheme, :color_scheme_id, :user_selectable, :remote_theme_id, :settings

  has_one :user, serializer: UserNameSerializer, embed: :object

  has_many :theme_fields, serializer: ThemeFieldSerializer, embed: :objects
  has_many :child_themes, serializer: ChildThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects

  def child_themes
    object.child_themes.order(:name)
  end

  def settings
    object.settings.map { |setting| ThemeSettingsSerializer.new(setting, root: false) }
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
