module Onebox
  module Engine
    class FiveHundredPxOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/500px\.com\/photo\/\d+\//)
      always_https

      def to_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:image])
        "<img src='#{escaped_src}' width='#{og[:image_width]}' height='#{og[:image_height]}' #{Helpers.title_attr(og)}>"
      end

    end
  end
end
