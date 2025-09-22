# frozen_string_literal: true

module Onebox
  module Engine
    class TiktokOnebox
      include Engine
      include StandardEmbed

      matches_domain("tiktok.com", "www.tiktok.com", "m.tiktok.com")
      requires_iframe_origins "https://www.tiktok.com"
      always_https

      def self.matches_path(path)
        path.match?(%r{^(/@.+/video/\d+|/v/\d+)(/\w+)?/?$})
      end

      def self.embed_url(video_id)
        "https://www.tiktok.com/embed/v2/#{video_id}"
      end

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
        video_height = oembed_data.thumbnail_height < 1024 ? 998 : oembed_data.thumbnail_height
        height = (323.0 / 576) * video_height

        <<-HTML
          <iframe
            class="tiktok-onebox"
            src="#{self.class.embed_url(oembed_data.embed_product_id)}"
            sandbox="allow-popups allow-popups-to-escape-sandbox allow-scripts allow-top-navigation allow-same-origin"
            frameborder="0"
            seamless="seamless"
            scrolling="no"
            style="
              min-width: 323px;
              height: #{height}px;
              border: 4px solid #fff;
              border-top: 3px solid #fff;
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
