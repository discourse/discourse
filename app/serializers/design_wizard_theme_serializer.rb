# frozen_string_literal: true

class DesignWizardThemeSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :description,
             :default,
             :color_scheme_id,
             :dark_color_scheme_id,
             :screenshot_light_url,
             :screenshot_dark_url,
             :palette_pairs

  def description
    object.description(preloaded_locale_fields: object.locale_fields)
  end

  def default
    object.default?
  end

  def screenshot_light_url
    ThemeScreenshotThumbnails.url_for(object, "screenshot_light") || object.screenshot_light_url
  end

  def screenshot_dark_url
    ThemeScreenshotThumbnails.url_for(object, "screenshot_dark") || object.screenshot_dark_url
  end

  def palette_pairs
    DesignWizard::PalettePairs.for_theme(object)
  end
end
