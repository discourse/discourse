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

    attributes(*STORED_ATTRIBUTES.map(&:to_sym), :preview_url)

    # Themes are plugin store documents, not models.
    STORED_ATTRIBUTES.each { |attribute| define_method(attribute) { object[attribute] } }

    # Only activated copies carry a snapshot id.
    def include_snapshot?
      object.key?("snapshot")
    end

    def preview_url
      ThemePreview.url(ThemePreview.token_for(object))
    end
  end
end
