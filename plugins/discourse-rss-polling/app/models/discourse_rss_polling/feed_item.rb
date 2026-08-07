# frozen_string_literal: true

require_dependency "feed_item_accessor"

module DiscourseRssPolling
  class FeedItem
    def initialize(rss_item, accessor = ::FeedItemAccessor)
      @accessor = accessor.new(rss_item)
    end

    def url
      return @url if defined?(@url)

      @url = FeedUrl.http?(@accessor.link) ? @accessor.link : @accessor.element_content(:id)
    end

    def content
      return @content if defined?(@content)

      @content =
        if is_youtube?
          url
        else
          value = nil
          CONTENT_ELEMENT_TAG_NAMES.each do |tag_name|
            break if value = @accessor.element_content(tag_name)
          end
          value&.force_encoding("UTF-8")&.scrub
        end
    end

    def title
      return @title if defined?(@title)

      @title =
        begin
          unclean_title = @accessor.element_content(:title)&.force_encoding("UTF-8")&.scrub
          unclean_title =
            TextCleaner.clean_title(TextSentinel.title_sentinel(unclean_title).text).presence
          CGI.unescapeHTML(unclean_title) if unclean_title
        end
    end

    def categories
      @categories ||=
        Array(@accessor.element_content(:categories))
          .map do |category|
            if category.respond_to?(:content)
              category.content.presence
            elsif category.respond_to?(:term)
              category.term
            end
          end
          .compact
    end

    def image_link
      @accessor.element_content(:itunes_image)&.href
    end

    def is_youtube?
      url&.starts_with?("https://www.youtube.com/watch")
    end

    def pubdate
      return @pubdate if defined?(@pubdate)

      @pubdate =
        begin
          raw =
            @accessor.element_content(:pubDate) || @accessor.element_content(:published) ||
              @accessor.element_content(:updated)
          if raw.blank?
            nil
          elsif raw.respond_to?(:iso8601)
            raw
          else
            Time.zone.parse(raw.to_s)
          end
        rescue ArgumentError, TypeError
          nil
        end
    end

    def outcome(status:, reason: nil, topic_url: nil)
      {
        "title" => title,
        "url" => url,
        "status" => status.to_s,
        "reason" => reason&.to_s,
        "categories" => categories,
        "published_at" => pubdate&.iso8601,
        "topic_url" => topic_url,
      }
    end

    private

    CONTENT_ELEMENT_TAG_NAMES = %i[content_encoded content description summary]
  end
end
