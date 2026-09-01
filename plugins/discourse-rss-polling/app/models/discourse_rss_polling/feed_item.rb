# frozen_string_literal: true

require_dependency "feed_item_accessor"

module DiscourseRssPolling
  class FeedItem
    CONTENT_ELEMENT_TAG_NAMES = %i[content_encoded content description summary]
    MINIMUM_TEXT_LENGTH_TO_TRUNCATE = 500
    MARKDOWN_COMPATIBLE_TAG_NAMES = %w[
      a
      abbr
      b
      br
      code
      del
      em
      i
      img
      ins
      kbd
      mark
      q
      s
      small
      span
      strong
      sub
      sup
      time
      u
    ]
    def initialize(rss_item, accessor = ::FeedItemAccessor)
      @accessor = accessor.new(rss_item)
    end

    def url
      return @url if defined?(@url)

      @url = FeedUrl.http?(@accessor.link) ? @accessor.link : @accessor.element_content(:id)
    end

    def content
      return @content if defined?(@content)

      value = @accessor.element_content(content_element_name) if content_element_name
      value ||= url
      @content = value.to_s.dup.force_encoding("UTF-8").scrub if value
    end

    def decoded_content
      @decoded_content ||= CGI.unescapeHTML(content.to_s)
    end

    def cook_method
      return Post.cook_methods[:regular] if content_element_name.nil?

      case @accessor.element_type(content_element_name).to_s.downcase
      when "text", "text/plain"
        Post.cook_methods[:regular]
      when "html", "text/html", "xhtml", "application/xhtml+xml"
        nil
      else
        Post.cook_methods[:regular] if markdown_compatible?
      end
    end

    def truncate_content?
      Nokogiri::HTML5.fragment(decoded_content).text.squish.length > MINIMUM_TEXT_LENGTH_TO_TRUNCATE
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

    def content_element_name
      return @content_element_name if defined?(@content_element_name)

      @content_element_name =
        CONTENT_ELEMENT_TAG_NAMES.find { |tag_name| @accessor.element_content(tag_name).present? }
    end

    def markdown_compatible?
      tag_names = decoded_content.scan(%r{</?([a-z][a-z0-9-]*)(?:\s[^>]*)?/?>}i).flatten
      tag_names.all? { |tag_name| MARKDOWN_COMPATIBLE_TAG_NAMES.include?(tag_name.downcase) }
    end
  end
end
