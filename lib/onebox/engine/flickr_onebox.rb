module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/www\.flickr\.com\/photos\//)
      always_https

      def to_html
        og = get_opengraph
        "<img src='#{og[:image]}' width='#{og[:image_width]}' height='#{og[:image_height]}' #{Helpers.title_attr(og)}>"
      end

    end
  end
end
