# frozen_string_literal: true

module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include StandardEmbed

      matches_domain("soundcloud.com", "www.soundcloud.com")
      always_https
      requires_iframe_origins "https://w.soundcloud.com"

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
        oembed_url = "https://soundcloud.com/oembed.json?url=#{url}"
        oembed_url += "&maxheight=166" unless url["/sets/"]
        oembed_url
      end
    end
  end
end
