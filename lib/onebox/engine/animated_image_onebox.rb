# frozen_string_literal: true

module Onebox
  module Engine
    class AnimatedImageOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/.*(giphy\.com|gph\.is|tenor\.com)\//)
      always_https

      def to_html
        og = get_opengraph
        "<img src='#{og.image}' width='#{og.image_width}' height='#{og.image_height}' class='animated onebox' #{og.title_attr}>"
      end
    end
  end
end
