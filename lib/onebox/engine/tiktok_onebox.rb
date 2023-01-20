# frozen_string_literal: true

module Onebox
  module Engine
    class TiktokOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://((?:m|www)\.)?tiktok\.com(?:/@(.+)\/video/|/v/)\d+(/\w+)?/?})
      requires_iframe_origins "https://www.tiktok.com"
      always_https

      def placeholder_html
        <<-HTML
          <img
            src="#{oembed_data.thumbnail_url}"
            title="#{oembed_data.title}"
            style="
              max-width: #{oembed_data.thumbnail_width / 2}px;
              max-height: #{oembed_data.thumbnail_height / 2}px;"
          >
        HTML
      end

      def to_html
        height = oembed_data.thumbnail_width >= oembed_data.thumbnail_height ? 727 : 742

        <<-HTML
          <iframe
            class="tiktok-onebox"
            src="https://www.tiktok.com/embed/v2/#{oembed_data.embed_product_id}"
            sandbox="allow-popups allow-popups-to-escape-sandbox allow-scripts allow-top-navigation allow-same-origin"
            frameborder="0"
            seamless="seamless"
            scrolling="no"
            style="
              min-width: 332px;
              height: #{height}px;
              border-top: 3px solid #fff;
              border-radius: 9px;
              background-color: #fff;
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
