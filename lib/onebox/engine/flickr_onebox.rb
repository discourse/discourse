module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/www\.flickr\.com\/photos\//)
      always_https

      def to_html
        og = get_opengraph
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:image])
        "<img src='#{escaped_src}' width='#{og[:image_width]}' height='#{og[:image_height]}' #{Helpers.title_attr(og)}>"
      end

    end
  end
end
