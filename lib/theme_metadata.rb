# frozen_string_literal: true

class ThemeMetadata
  OFFICIAL_THEMES =
    Set.new(
      %w[
        discourse-brand-header
        discourse-category-banners
        discourse-clickable-topic
        discourse-custom-header-links
        Discourse-easy-footer
        discourse-gifs
        discourse-topic-thumbnails
        discourse-search-banner
        discourse-unanswered-filter
        discourse-versatile-banner
        DiscoTOC
        unformatted-code-detector
      ],
    ).to_a
end
