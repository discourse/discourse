# frozen_string_literal: true

module Onebox
  module Engine
    class SimplecastOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{https?://(.+)?simplecast.com/(episodes|s)/.*})
      always_https
      requires_iframe_origins("https://player.simplecast.com")

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
        "https://api.simplecast.com/oembed?url=#{url}"
      end
    end
  end
end
