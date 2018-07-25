module Onebox
  module Engine
    module OpengraphImage

      def to_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:image])
        "<img src='#{escaped_src}' width='#{og[:image_width]}' height='#{og[:image_height]}' class='onebox' #{Helpers.title_attr(og)}>"
      end

    end
  end
end
