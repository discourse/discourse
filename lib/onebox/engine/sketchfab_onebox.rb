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
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(src)

        <<-HTML
          <iframe src="#{escaped_src}"
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
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(opengraph[:image])
        "<img src='#{escaped_src}'>"
      end

    end
  end
end
