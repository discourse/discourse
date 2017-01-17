module Onebox
  module Engine
    class BandCampOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*\.bandcamp\.com\/(album|track)\//)
      always_https

      def placeholder_html
        og = get_opengraph
        "<img src='#{og[:image]}' height='#{og[:video_height]}' #{Helpers.title_attr(og)}>"
      end

      def to_html
        og = get_opengraph
        src = og[:video_secure_url] || og[:video]

        <<-HTML
          <iframe src="#{src}"
                  width="#{og[:video_width]}"
                  height="#{og[:video_height]}"
                  scrolling="no"
                  frameborder="0"
                  allowfullscreen>
          </iframe>
        HTML
      end

    end
  end
end
