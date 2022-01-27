# frozen_string_literal: true

module Onebox
  module Engine
    class WistiaOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/https?:\/\/(.+)?(wistia.com|wi.st)\/(medias|embed)\/.*/)
      requires_iframe_origins("https://fast.wistia.com", "https://fast.wistia.net")
      always_https

      def to_html
        get_oembed.html
      end

      def placeholder_html
        oembed = get_oembed
        return if Onebox::Helpers.blank?(oembed.thumbnail_url)
        "<img src='#{oembed.thumbnail_url}' #{oembed.title_attr}>"
      end

      private

      def get_oembed_url
        "https://fast.wistia.com/oembed?embedType=iframe&url=#{url}"
      end
    end
  end
end
