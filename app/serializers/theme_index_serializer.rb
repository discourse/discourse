# frozen_string_literal: true

class ThemeIndexSerializer < BasicThemeSerializer
  attributes :user_selectable, :screenshot_url, :remote_theme_id, :enabled?, :supported?

  has_one :color_scheme, serializer: ColorSchemeSerializer, embed: :object
  has_one :remote_theme, serializer: RemoteThemeSerializer, embed: :objects
end
