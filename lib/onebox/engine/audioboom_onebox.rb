# frozen_string_literal: true

module Onebox
  module Engine
    class AudioboomOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/audioboom\.com\/posts\/\d+/)
      always_https

      def placeholder_html
        oembed = get_oembed

        <<-HTML
          <img
            src="#{oembed.thumbnail_url}"
            style="max-width: #{oembed.width}px; max-height: #{oembed.height}px;"
            #{oembed.title_attr}
          >
        HTML
      end

      def to_html
        get_oembed.html
      end
    end
  end
end
