# frozen_string_literal: true

module ::Blog
  class BlogThemeSerializer < ApplicationSerializer
    STORED_ATTRIBUTES = [
      "id",
      "revision",
      "source",
      "locally_modified",
      "snapshot",
      *BlogTheme::FIELDS,
    ].freeze

    attributes(
      *STORED_ATTRIBUTES.map(&:to_sym),
      :preset,
      :description,
      :screenshot_light_url,
      :screenshot_dark_url,
      :preview_url,
    )

    # Themes are plugin store documents, not models.
    STORED_ATTRIBUTES.each { |attribute| define_method(attribute) { object[attribute] } }

    # Only activated copies carry a snapshot id.
    def include_snapshot?
      object.key?("snapshot")
    end

    def preset
      object["preset"] == true
    end

    def description
      object["description"]
    end

    def include_description?
      object["description"].present?
    end

    def screenshot_light_url
      object["screenshot_light_url"]
    end

    def include_screenshot_light_url?
      object["screenshot_light_url"].present?
    end

    def screenshot_dark_url
      object["screenshot_dark_url"]
    end

    def include_screenshot_dark_url?
      object["screenshot_dark_url"].present?
    end

    def preview_url
      ThemePreview.url(ThemePreview.token_for(object))
    end
  end
end
