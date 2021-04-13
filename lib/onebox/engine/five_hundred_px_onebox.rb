# frozen_string_literal: true

module Onebox
  module Engine
    class FiveHundredPxOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/500px\.com\/photo\/\d+\//)
      always_https

      def to_html
        og = get_opengraph
        "<img src='#{og.image}' width='#{og.image_width}' height='#{og.image_height}' class='onebox' #{og.title_attr}>"
      end
    end
  end
end
