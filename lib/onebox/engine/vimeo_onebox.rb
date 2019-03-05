module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?vimeo\.com\/\d+(\/[^\/]+)?$/)
      always_https

      def placeholder_html
        oembed = get_oembed
        "<img src='#{oembed.thumbnail_url}' width='#{oembed.thumbnail_width}' height='#{oembed.thumbnail_height}' #{oembed.title_attr}>"
      end

      def to_html
        get_oembed.html
      end
    end
  end
end
