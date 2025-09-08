# frozen_string_literal: true

require_dependency "feed_item_accessor"

module DiscourseRssPolling
  class FeedItem
    def initialize(rss_item, accessor = ::FeedItemAccessor)
      @accessor = accessor.new(rss_item)
    end

    def url
      url?(@accessor.link) ? @accessor.link : @accessor.element_content(:id)
    end

    def content
      content = nil

      CONTENT_ELEMENT_TAG_NAMES.each do |tag_name|
        break if content = @accessor.element_content(tag_name)
      end

      return url if is_youtube?

      content&.force_encoding("UTF-8")&.scrub
    end

    def title
      unclean_title = @accessor.element_content(:title)&.force_encoding("UTF-8")&.scrub
      unclean_title =
        TextCleaner.clean_title(TextSentinel.title_sentinel(unclean_title).text).presence
      CGI.unescapeHTML(unclean_title) if unclean_title
    end

    def categories
      @accessor.element_content(:categories).map { |c| c.content }
    end

    def image_link
      @accessor.element_content(:itunes_image)&.href
    end

    def is_youtube?
      url&.starts_with?("https://www.youtube.com/watch")
    end

    def pubdate
      @accessor.element_content(:pubDate) || @accessor.element_content(:published)
    end

    private

    # The tag name's relative order implies its priority.
    CONTENT_ELEMENT_TAG_NAMES = %i[content_encoded content description summary]

    def url?(link)
      link.present? && link =~ %r{^https?\://}
    end
  end
end
