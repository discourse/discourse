# frozen_string_literal: true

module Onebox
  module Engine
    class SimplecastOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/https?:\/\/(.+)?simplecast.com\/(episodes|s)\/.*/)
      always_https
      requires_iframe_origins("https://embed.simplecast.com")

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
        if id = url.scan(/([a-zA-Z0-9]*)\Z/).flatten.first
          oembed_url = "https://simplecast.com/s/#{id}"
        else
          oembed_url = url
        end

        "https://simplecast.com/oembed?url=#{oembed_url}"
      end
    end
  end
end
