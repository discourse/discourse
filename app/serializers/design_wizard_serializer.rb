# frozen_string_literal: true

class DesignWizardSerializer < ApplicationSerializer
  attributes :current_theme, :base_font, :heading_font, :homepage, :palettes_user_selectable

  attributes :themes
  attributes :additional_homepages, :homepage_settings

  def additional_homepages
    DesignWizard::Homepages.additional_options
  end

  def homepage_settings
    DesignWizard::Homepages.current_settings
  end

  def themes
    @options[:themes].map do |theme|
      DesignWizardThemeSerializer.new(theme, scope:, root: false).as_json
    end + DesignWizard::Themes.available_to_install(@options[:themes], guardian: scope)
  end

  def current_theme
    return if object.nil? || @options[:themes].any? { |theme| theme.id == object.id }

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

  def preselected_theme
    return object if @options[:themes].any? { |theme| theme.id == object&.id }

    Theme.horizon_theme
  end
end
