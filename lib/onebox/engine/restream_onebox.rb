# frozen_string_literal: true

module Onebox
  module Engine
    class RestreamOnebox
      include Engine
      include StandardEmbed

      matches_domain("player.restream.io")
      always_https
      requires_iframe_origins "https://player.restream.io"

      class << self
        def matches_path(path)
          path.nil? || path.empty? || path == "/"
        end
      end

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
      end

      def to_html
        width = @options[:max_width] || 695
        height = (width * 9.0 / 16).round

        <<~HTML
          <iframe
            class="restream-onebox"
            src="#{url}"
            width="#{width}"
            height="#{height}"
            frameborder="0"
            allowfullscreen
          ></iframe>
        HTML
      end
    end
  end
end
