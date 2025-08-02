# frozen_string_literal: true

module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include StandardEmbed

      matches_domain("imgur.com", "www.imgur.com")
      always_https

      def to_html
        og = get_opengraph
        return video_html(og) if !og.video_secure_url.nil?
        return album_html(og) if is_album?
        return image_html(og) if !og.image.nil?
        nil
      end

      private

      def video_html(og)
        <<-HTML
            <video width='#{og.video_width}' height='#{og.video_height}' #{og.title_attr} controls loop>
              <source src='#{og.video_secure_url}' type='video/mp4'>
              <source src='#{og.video_secure_url.gsub("mp4", "webm")}' type='video/webm'>
            </video>
          HTML
      end

      def album_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        album_title = "[Album] #{og.title}"

        <<-HTML
            <div class='onebox imgur-album'>
              <a href='#{escaped_url}' target='_blank' rel='noopener'>
                <span class='outer-box' style='width:#{og.image_width}px'>
                  <span class='inner-box'>
                    <span class='album-title'>#{album_title}</span>
                  </span>
                </span>
                <img src='#{og.secure_image_url}' #{og.title_attr} height='#{og.image_height}' width='#{og.image_width}'>
              </a>
            </div>
          HTML
      end

      def is_album?
        response =
          begin
            Onebox::Helpers.fetch_response("https://api.imgur.com/oembed.json?url=#{url}")
          rescue StandardError
            "{}"
          end
        oembed_data = ::MultiJson.load(response, symbolize_keys: true)
        imgur_data_id = Nokogiri.HTML(oembed_data[:html]).xpath("//blockquote").attr("data-id")
        imgur_data_id.to_s[%r{a/}]
      end

      def image_html(og)
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)

        <<-HTML
            <a href='#{escaped_url}' target='_blank' rel='noopener' class="onebox">
              <img src='#{og.secure_image_url.chomp("?fb")}' #{og.title_attr} alt='Imgur'>
            </a>
          HTML
      end
    end
  end
end
