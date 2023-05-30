# frozen_string_literal: true

module Onebox
  module Engine
    class TiktokOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://((?:m|www)\.)?tiktok\.com(?:/@(.+)\/video/|/v/)\d+(/\w+)?/?})
      requires_iframe_origins "https://www.tiktok.com"
      always_https

      TIKTOK_HEIGHT = 582
      TIKTOK_WIDTH = 332

      def placeholder_html
        <<-HTML
          <img
            src="#{oembed_data.thumbnail_url}"
            title="#{oembed_data.title}"
            style="
              width: #{TIKTOK_WIDTH}px;
              height: #{TIKTOK_HEIGHT}px;"
          >
        HTML
      end

      def to_html
        <<-HTML
          <iframe
            class="tiktok-onebox"
            src="https://www.tiktok.com/embed/v2/#{oembed_data.embed_product_id}"
            sandbox="allow-popups allow-popups-to-escape-sandbox allow-scripts allow-top-navigation allow-same-origin"
            frameborder="0"
            seamless="seamless"
            scrolling="no"
            style="
              width: #{TIKTOK_WIDTH}px;
              height: #{TIKTOK_HEIGHT}px;
              "
          ></iframe>
        HTML
      end

      private

      def oembed_data
        @oembed_data = get_oembed
      end

      def get_oembed_url
        "https://www.tiktok.com/oembed?url=#{url}"
      end
    end
  end
end
