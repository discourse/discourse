module Onebox
  module Engine
    class KalturaOnebox
      include Engine
      include StandardEmbed

      always_https
      matches_regexp(/^https?:\/\/[a-z0-9]+\.kaltura\.com\/id\/[a-zA-Z0-9]+/)

      def preview_html
        og = get_opengraph
        thumbnail_url = ::Onebox::Helpers.normalize_url_for_output(og[:image_secure_url])

        <<~HTML
          <img src="#{thumbnail_url}" width="#{og[:video_width]}" height="#{og[:video_height]}" >
        HTML
      end

      def to_html
        og = get_opengraph
        embedded_video_url = ::Onebox::Helpers.normalize_url_for_output(og[:video_secure_url])

        <<~HTML
          <iframe src="#{embedded_video_url}"
                  width="#{og[:video_width]}" height="#{og[:video_height]}"
                  frameborder='0'
                  allowfullscreen >
          </iframe>
        HTML
      end
    end
  end
end
