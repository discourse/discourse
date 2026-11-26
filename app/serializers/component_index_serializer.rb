# frozen_string_literal: true

class ComponentIndexSerializer < BasicThemeSerializer
  attributes :remote_theme_id, :supported?, :enabled?, :disabled_at

  has_one :user, serializer: UserNameSerializer, embed: :object
  has_one :disabled_by, serializer: UserNameSerializer, embed: :object

  has_many :parent_themes, serializer: BasicThemeSerializer, embed: :objects
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects

  # Falls back to the description of a popular component, for components
  # that don't describe themselves.
  def description
    super.presence || PopularThemes.description_for(object.remote_theme&.remote_url)
  end

  def parent_themes
    object.parent_themes
  end

  def include_disabled_at?
    object.component? && !object.enabled?
  end

  def include_disabled_by?
    include_disabled_at?
  end
end
