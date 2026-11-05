# frozen_string_literal: true

module ::Blog
  # Absolute URLs keep cooked HTML working on the blog domain, in feeds and in review snapshots.
  module ArticleHtml
    URL_ATTRIBUTES = %w[href src poster].freeze

    class << self
      def render(cooked)
        doc = Nokogiri::HTML5.fragment(cooked.to_s)
        doc.css("[href], [src], [poster]").each { |element| absolutize_attributes(element) }
        doc
          .css("[srcset]")
          .each { |element| element["srcset"] = absolute_srcset(element["srcset"]) }
        doc.css(".spoiler").each { |element| element["tabindex"] = "0" }
        doc.to_html.html_safe
      end

      private

      def absolutize_attributes(element)
        URL_ATTRIBUTES.each do |attribute|
          value = element[attribute]
          next if !root_relative?(value)
          element[attribute] = (
            if attribute == "href"
              UrlHelper.absolute_without_cdn(value)
            else
              UrlHelper.absolute(value)
            end
          )
        end
      end

      def absolute_srcset(srcset)
        srcset
          .split(",")
          .map do |candidate|
            url, descriptor = candidate.strip.split(/\s+/, 2)
            url = UrlHelper.absolute(url) if root_relative?(url)
            [url, descriptor].compact.join(" ")
          end
          .join(", ")
      end

      def root_relative?(url)
        url.present? && url.start_with?("/") && !url.start_with?("//")
      end
    end
  end
end
