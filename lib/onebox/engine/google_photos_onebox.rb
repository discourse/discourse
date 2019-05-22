# frozen_string_literal: true

module Onebox
  module Engine
    class GooglePhotosOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(photos)\.(app\.goo\.gl|google\.com)/)
      always_https

      def to_html
        og = get_opengraph
        return video_html(og) if !og.video_secure_url.nil?
        return album_html(og) if !og.type.nil? && og.type == "google_photos:photo_album"
        return image_html(og) if !og.image.nil?
        nil
      end

      private

      def video_html(og)
        <<-HTML
            <video width='#{og.video_width}' height='#{og.video_height}' #{og.title_attr} poster="#{og.get_secure_image}" controls loop>
              <source src='#{og.video_secure_url}' type='video/mp4'>
            </video>
          HTML
      end

      def album_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        album_title = og.description.nil? ? og.title : "[#{og.description}] #{og.title}"

        <<-HTML
            <div class='onebox google-photos-album'>
              <a href='#{escaped_url}' target='_blank'>
                <span class='outer-box' style='width:#{og.image_width}px'>
                  <span class='inner-box'>
                    <span class='album-title'>#{Onebox::Helpers.truncate(album_title, 80)}</span>
                  </span>
                </span>
                <img src='#{og.get_secure_image}' #{og.title_attr} height='#{og.image_height}' width='#{og.image_width}'>
              </a>
            </div>
          HTML
      end

      def image_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)

        <<-HTML
            <a href='#{escaped_url}' target='_blank' class="onebox">
              <img src='#{og.get_secure_image}' #{og.title_attr} alt='Google Photos' height='#{og.image_height}' width='#{og.image_width}'>
            </a>
          HTML
      end
    end
  end
end
