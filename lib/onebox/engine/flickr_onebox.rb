# frozen_string_literal: true

require_relative './opengraph_image'

module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/www\.flickr\.com\/photos\//)
      always_https

      def to_html
        og = get_opengraph
        return album_html(og) if og.url =~ /\/sets\//
        return image_html(og) if !og.image.nil?
        nil
      end

      private

      def album_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        album_title = "[Album] #{og.title}"

        <<-HTML
          <div class='onebox flickr-album'>
            <a href='#{escaped_url}' target='_blank' rel='noopener'>
              <span class='outer-box' style='max-width:#{og.image_width}px'>
                <span class='inner-box'>
                  <span class='album-title'>#{album_title}</span>
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
            <img src='#{og.secure_image_url}' #{og.title_attr} alt='Imgur' height='#{og.image_height}' width='#{og.image_width}'>
          </a>
        HTML
      end
    end
  end
end
