class ThemeFieldSerializer < ApplicationSerializer
  attributes :name, :target, :value

  def target
    case object.target
    when 0 then "common"
    when 1 then "desktop"
    when 2 then "mobile"
    end
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
  attributes :color_scheme, :color_scheme_id, :user_selectable, :remote_theme_id

  has_many :theme_fields, serializer: ThemeFieldSerializer, embed: :objects
  has_many :child_themes, serializer: ChildThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects
end
