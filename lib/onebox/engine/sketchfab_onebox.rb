module Onebox
  module Engine
    class SketchFabOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/sketchfab\.com\/models\/[a-z0-9]{32}/)
      always_https

      def to_html
        opengraph = get_opengraph

        src = opengraph[:video_url].gsub("?autostart=1", "")

        <<-HTML
          <iframe src="#{src}"
                  width="#{opengraph[:video_width]}"
                  height="#{opengraph[:video_height]}"
                  scrolling="no"
                  frameborder="0"
                  allowfullscreen>
          </iframe>
        HTML
      end

      def placeholder_html
        opengraph = get_opengraph
        "<img src='#{opengraph[:image]}'>"
      end

    end
  end
end
