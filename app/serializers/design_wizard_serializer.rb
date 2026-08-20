# frozen_string_literal: true

class DesignWizardSerializer < ApplicationSerializer
  attributes :current_theme, :base_font, :heading_font, :homepage, :palettes_user_selectable

  has_many :themes, serializer: DesignWizardThemeSerializer, embed: :objects

  def themes
    @options[:themes]
  end

  def current_theme
    return if object.nil? || Theme::CORE_THEMES.value?(object.id)

    { id: object.id, name: object.name }
  end

  def base_font
    SiteSetting.base_font
  end

  def heading_font
    SiteSetting.heading_font
  end

  def homepage
    SiteSetting.homepage
  end

  def palettes_user_selectable
    offered = ColorScheme.where(theme_id: preselected_theme&.id)
    offered = ColorScheme.where(via_wizard: true) if offered.none?
    offered.exists? && offered.where(user_selectable: false).none?
  end

  private

  # The wizard offers Horizon when the current default is not a core theme.
  def preselected_theme
    return object if Theme::CORE_THEMES.value?(object&.id)

    Theme.horizon_theme
  end
end
