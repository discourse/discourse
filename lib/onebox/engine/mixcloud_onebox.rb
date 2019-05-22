# frozen_string_literal: true

module Onebox
  module Engine
    class MixcloudOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/www\.mixcloud\.com\//)
      always_https

      def placeholder_html
        oembed = get_oembed
        "<img src='#{oembed.image}' height='#{oembed.height}' #{oembed.title_attr}>"
      end

      def to_html
        get_oembed.html
      end
    end
  end
end
