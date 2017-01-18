module Onebox
  module Engine
    class MixcloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/www\.mixcloud\.com\//)
      always_https

      def placeholder_html
        oembed = get_oembed
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(oembed[:image])
        "<img src='#{escaped_src}' height='#{oembed[:height]}' #{Helpers.title_attr(oembed)}>"
      end

      def to_html
        get_oembed[:html]
      end
    end
  end
end
