module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?vimeo\.com\/\d+$/)
      always_https

      def placeholder_html
        oembed = get_oembed
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(oembed[:thumbnail_url])
        "<img src='#{escaped_src}' width='#{oembed[:thumbnail_width]}' height='#{oembed[:thumbnail_height]}' #{Helpers.title_attr(oembed)}>"
      end

      def to_html
        get_oembed[:html]
      end
    end
  end
end
