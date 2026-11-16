# frozen_string_literal: true

class DesignWizardThemeSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :default,
             :default_homepage,
             :color_scheme_id,
             :dark_color_scheme_id,
             :screenshot_light_url,
             :screenshot_dark_url,
             :palette_pairs

  def description
    if definition[:description_key]
      I18n.t(definition[:description_key])
    else
      object.description(preloaded_locale_fields: object.locale_fields)
    end
  end

  def default
    object.default?
  end

  def default_homepage
    definition.fetch(:default_homepage) { "latest" if Theme::CORE_THEMES.value?(object.id) }
  end

  def screenshot_light_url
    preview_url("light") || ThemeScreenshotThumbnails.url_for(object, "screenshot_light") ||
      object.screenshot_light_url
  end

  def screenshot_dark_url
    preview_url("dark") || ThemeScreenshotThumbnails.url_for(object, "screenshot_dark") ||
      object.screenshot_dark_url
  end

  def palette_pairs
    DesignWizard::PalettePairs.for_theme(object)
  end

  private

  def definition
    @definition ||= DesignWizard::Themes.definition_for(object) || {}
  end

  def preview_url(mode)
    name = Theme::CORE_THEMES.key(object.id)
    if name
      "#{Discourse.base_path}/images/design-wizard/#{name}-#{mode}.webp"
    elsif definition[:"screenshot_#{mode}_url"]
      Discourse.base_path + definition[:"screenshot_#{mode}_url"]
    end
  end
end
