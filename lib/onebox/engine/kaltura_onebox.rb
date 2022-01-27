# frozen_string_literal: true

module Onebox
  module Engine
    class KalturaOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_regexp(/^https?:\/\/[a-z0-9]+\.kaltura\.com\/id\/[a-zA-Z0-9]+/)
      requires_iframe_origins "https://*.kaltura.com"

      def preview_html
        og = get_opengraph

        <<~HTML
          <img src="#{og.image_secure_url}" width="#{og.video_width}" height="#{og.video_height}">
        HTML
      end

      def to_html
        og = get_opengraph

        <<~HTML
          <iframe
            src="#{og.video_secure_url}"
            width="#{og.video_width}"
            height="#{og.video_height}"
            frameborder='0'
            allowfullscreen
          ></iframe>
        HTML
      end
    end
  end
end
