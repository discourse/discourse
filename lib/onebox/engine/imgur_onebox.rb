module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?imgur\.com/)
      always_https

      def to_html
        og = get_opengraph
        return video_html(og) if !Onebox::Helpers::blank?(og[:video_secure_url])
        return album_html(og) if is_album?
        return image_html(og) if !Onebox::Helpers::blank?(og[:image])
        nil
      end

      private

        def video_html(og)
          escaped_src = ::Onebox::Helpers.normalize_url_for_output(og[:video_secure_url])

          <<-HTML
            <video width='#{og[:video_width]}' height='#{og[:video_height]}' #{Helpers.title_attr(og)} controls loop>
              <source src='#{escaped_src}' type='video/mp4'>
              <source src='#{escaped_src.gsub('mp4', 'webm')}' type='video/webm'>
            </video>
          HTML
        end

        def album_html(og)
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
          escaped_src = ::Onebox::Helpers.normalize_url_for_output(get_secure_link(og[:image]))

          <<-HTML
            <div class='onebox imgur-album'>
              <a href='#{escaped_url}' target='_blank'>
                <span class='outer-box' style='width:#{og[:image_width]}px'>
                  <span class='inner-box'>
                    <span class='album-title'>[Album] #{og[:title]}</span>
                  </span>
                </span>
                <img src='#{escaped_src}' #{Helpers.title_attr(og)} height='#{og[:image_height]}' width='#{og[:image_width]}'>
              </a>
            </div>
          HTML
        end

        def is_album?
          response = Onebox::Helpers.fetch_response("http://api.imgur.com/oembed.json?url=#{url}") rescue "{}"
          oembed_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
          imgur_data_id = Nokogiri::HTML(oembed_data[:html]).xpath("//blockquote").attr("data-id")
          imgur_data_id.to_s[/a\//]
        end

        def image_html(og)
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
          escaped_src = ::Onebox::Helpers.normalize_url_for_output(get_secure_link(og[:image]))

          <<-HTML
            <a href='#{escaped_url}' target='_blank'>
              <img src='#{escaped_src}' #{Helpers.title_attr(og)} alt='Imgur' height='#{og[:image_height]}' width='#{og[:image_width]}'>
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
