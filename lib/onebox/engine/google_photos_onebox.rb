module Onebox
  module Engine
    class GooglePhotosOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(photos)\.(app\.goo\.gl|google\.com)/)
      always_https

      def to_html
        og = get_opengraph
        return video_html(og) if !Onebox::Helpers::blank?(og[:video_secure_url])
        return album_html(og) if !Onebox::Helpers::blank?(og[:type]) && og[:type] == "google_photos:photo_album"
        return image_html(og) if !Onebox::Helpers::blank?(og[:image])
        nil
      end

      private

      def video_html(og)
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:video_secure_url])
        escaped_image_src = ::Onebox::Helpers.normalize_url_for_output(get_secure_link(og[:image]))

        <<-HTML
            <video width='#{og[:video_width]}' height='#{og[:video_height]}' #{Helpers.title_attr(og)} poster="#{escaped_image_src}" controls loop>
              <source src='#{escaped_src}' type='video/mp4'>
            </video>
          HTML
      end

      def album_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(get_secure_link(og[:image]))
        album_title = Onebox::Helpers::blank?(og[:description]) ? og[:title].strip : "[#{og[:description].strip}] #{og[:title].strip}"

        <<-HTML
            <div class='onebox google-photos-album'>
              <a href='#{escaped_url}' target='_blank'>
                <span class='outer-box' style='width:#{og[:image_width]}px'>
                  <span class='inner-box'>
                    <span class='album-title'>#{Onebox::Helpers.truncate(album_title, 80)}</span>
                  </span>
                </span>
                <img src='#{escaped_src}' #{Helpers.title_attr(og)} height='#{og[:image_height]}' width='#{og[:image_width]}'>
              </a>
            </div>
          HTML
      end

      def image_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(get_secure_link(og[:image]))

        <<-HTML
            <a href='#{escaped_url}' target='_blank' class="onebox">
              <img src='#{escaped_src}' #{Helpers.title_attr(og)} alt='Google Photos' height='#{og[:image_height]}' width='#{og[:image_width]}'>
            </a>
          HTML
      end

      def get_secure_link(link)
        secure_link = URI(link)
        secure_link.scheme = 'https'
        secure_link.to_s
      end
    end
  end
end
