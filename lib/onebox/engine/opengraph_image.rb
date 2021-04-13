# frozen_string_literal: true

module Onebox
  module Engine
    module OpengraphImage

      def to_html
        og = get_opengraph
        "<img src='#{og.image}' width='#{og.image_width}' height='#{og.image_height}' class='onebox' #{og.title_attr}>"
      end
    end
  end
end
