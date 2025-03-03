# frozen_string_literal: true

module Onebox
  module Engine
    class AnimatedImageOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_domain("giphy.com", "gph.is", "tenor.com")

      def to_html
        og = get_opengraph
        if og.image
          "<img src='#{og.image}' width='#{og.image_width}' height='#{og.image_height}' class='animated onebox' #{og.title_attr}>"
        else
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)
          "<img src='#{escaped_url}' class='animated onebox'>"
        end
      end
    end
  end
end
