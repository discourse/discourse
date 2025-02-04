# frozen_string_literal: true

module Onebox
  module Engine
    class AudioComOnebox
      include Engine
      include StandardEmbed

      always_https
      requires_iframe_origins "https://audio.com"
      matches_domain("audio.com")

      def to_html
        oembed = get_oembed
        oembed.html.gsub("visual=true", "visual=false")
      end

      def placeholder_html
        oembed = get_oembed
        return if oembed.thumbnail_url.blank?
        "<img src='#{oembed.thumbnail_url}' #{oembed.title_attr}>"
      end

      protected

      def get_oembed_url
        oembed_url = "https://api.audio.com/oembed?url=#{url}"
        oembed_url += "&maxheight=228" unless url["/collections/"]
        oembed_url
      end
    end
  end
end
