module Onebox
  module Engine
    class GfycatOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/gfycat\.com\//)
      always_https

      def to_html
        oembed = get_oembed
        src = Nokogiri::HTML::fragment(oembed[:html]).at_css("iframe")["src"]

        <<-HTML
          <iframe src="#{src}"
                  width="#{oembed[:width]}"
                  height="#{oembed[:height]}"
                  scrolling="no"
                  frameborder="0"
                  allowfullscreen>
          </iframe>
        HTML
      end

      def placeholder_html
        opengraph = get_opengraph

        <<-HTML
          <img src="#{opengraph[:image]}" width=""#{opengraph[:image_width]}" height=""#{opengraph[:image_height]}">
        HTML
      end

    end
  end
end
