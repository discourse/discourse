# frozen_string_literal: true

module Onebox
  module Engine
    class LoomOnebox
      include Engine
      include StandardEmbed

      matches_domain("loom.com", "www.loom.com")
      always_https
      requires_iframe_origins "https://www.loom.com"

      def self.matches_path(path)
        path.match?(%r{^/share/\w+(/\w+)?/?$})
      end

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
