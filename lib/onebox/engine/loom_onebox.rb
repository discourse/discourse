# frozen_string_literal: true

module Onebox
  module Engine
    class LoomOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://(www\.)?loom\.com/share/\w+(/\w+)?/?})
      requires_iframe_origins "https://www.loom.com"
      always_https

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
      end

      def to_html
        video_id = url.split("/").last
        video_src = "https://www.loom.com/embed/#{video_id}"

        <<~HTML
          <iframe
            class="loom-onebox"
            src="#{video_src}"
            frameborder="0"
            webkitallowfullscreen
            mozallowfullscreen
            allowfullscreen
          </iframe>
        HTML
      end
    end
  end
end
