# frozen_string_literal: true

module Onebox
  module Engine
    class SlidesOnebox
      include Engine
      include StandardEmbed

      matches_domain("slides.com")
      always_https
      requires_iframe_origins "https://slides.com"

      def self.matches_path(path)
        path.match?(%r{^/[\p{Alnum}_\-]+/[\p{Alnum}_\-]+$})
      end

      def to_html
        <<-HTML
          <iframe
            src="https://slides.com#{uri.path}/embed?style=light"
            width="576"
            height="420"
            scrolling="no"
            frameborder="0"
            webkitallowfullscreen
            mozallowfullscreen
            allowfullscreen
          ></iframe>
        HTML
      end

      def placeholder_html
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(raw[:image])
        "<img src='#{escaped_src}'>"
      end
    end
  end
end
