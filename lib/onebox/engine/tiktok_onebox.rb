# frozen_string_literal: true

module Onebox
  module Engine
    class TiktokOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://(www\.)?tiktok\.com/@(.+)/video/\d+(/\w+)?/?})
      requires_iframe_origins "https://www.tiktok.com"
      always_https

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
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
              min-width: 332px;
              height: 742px;
              overflow: hidden;
              padding-top: 3px;
              background-color: #fff;
              border-radius: 9px;
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
