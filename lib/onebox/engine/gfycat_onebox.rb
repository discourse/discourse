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
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(src)

        <<-HTML
          <iframe src="#{escaped_src}"
                  width="#{oembed[:width]}"
                  height="#{oembed[:height]}"
                  scrolling="no"
                  frameborder="0"
                  allowfullscreen>
          </iframe>
        HTML
      end

      def placeholder_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:image])

        <<-HTML
          <img src="#{escaped_src}" width="#{og[:image_width]}" height="#{og[:image_height]}">
        HTML
      end

    end
  end
end
