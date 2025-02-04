# frozen_string_literal: true

module Onebox
  module Engine
    class GooglePhotosOnebox
      include Engine
      include StandardEmbed

      matches_domain("photos.google.com", "photos.app.goo.gl")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/.*$})
      end

      def to_html
        og = get_opengraph
        return video_html(og) if og.video_secure_url
        return album_html(og) if og.type == "google_photos:photo_album"
        return image_html(og) if og.image
        nil
      end

      private

      def video_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)

        <<-HTML
          <aside class="onebox google-photos">
            <header class="source">
              <img src="#{raw[:favicon]}" class="site-icon" width="16" height="16">
              <a href="#{escaped_url}" target="_blank" rel="nofollow ugc noopener">#{raw[:site_name]}</a>
            </header>
            <article class="onebox-body">
              <h3><a href="#{escaped_url}" target="_blank" rel="nofollow ugc noopener">#{og.title}</a></h3>
              <div class="aspect-image-full-size">
                <a href="#{escaped_url}" target="_blank" rel="nofollow ugc noopener" class="image-wrapper">
                  <img src="#{og.secure_image_url}" class="scale-image"/>
                  <span class="video-icon"></span>
                </a>
              </div>
            </article>
          </aside>
        HTML
      end

      def album_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        album_title = og.description.nil? ? og.title : "[#{og.description}] #{og.title}"

        <<-HTML
          <div class='onebox google-photos-album'>
            <a href='#{escaped_url}' target='_blank' rel='noopener'>
              <span class='outer-box' style='width:#{og.image_width}px'>
                <span class='inner-box'>
                  <span class='album-title'>#{Onebox::Helpers.truncate(album_title, 80)}</span>
                </span>
              </span>
              <img src='#{og.secure_image_url}' #{og.title_attr} height='#{og.image_height}' width='#{og.image_width}'>
            </a>
          </div>
        HTML
      end

      def image_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)

        <<-HTML
          <a href='#{escaped_url}' target='_blank' rel='noopener' class="onebox">
            <img src='#{og.secure_image_url}' #{og.title_attr} alt='Google Photos' height='#{og.image_height}' width='#{og.image_width}'>
          </a>
        HTML
      end
    end
  end
end
