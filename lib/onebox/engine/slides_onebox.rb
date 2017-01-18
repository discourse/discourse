module Onebox
  module Engine
    class SlidesOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/slides\.com\/[\p{Alnum}_\-]+\/[\p{Alnum}_\-]+$/)

      def to_html
        <<-HTML
          <iframe src="//slides.com#{uri.path}/embed?style=light"
                  width="576"
                  height="420"
                  scrolling="no"
                  frameborder="0"
                  webkitallowfullscreen
                  mozallowfullscreen
                  allowfullscreen>
          </iframe>
        HTML
      end

      def placeholder_html
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(raw[:image])
        "<img src='#{escaped_src}'>"
      end

    end
  end
end
