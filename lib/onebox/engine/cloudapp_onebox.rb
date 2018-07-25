module Onebox
  module Engine
    class CloudAppOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/cl\.ly/)
      always_https

      def to_html
        og = get_opengraph

        if !Onebox::Helpers::blank?(og[:image])
          return image_html(og)
        elsif og[:title].to_s[/\.(mp4|ogv|webm)$/]
          return video_html(og)
        else
          return link_html(og)
        end
      end

      private

        def link_html(og)
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(og[:url])

          <<-HTML
            <a href='#{escaped_url}' target='_blank'>
              #{og[:title]}
            </a>
          HTML
        end

        def video_html(og)
          src = og[:url]
          title = og[:title]
          direct_src = ::Onebox::Helpers.normalize_url_for_output("#{src}/#{title}")

          <<-HTML
            <video width='480' height='360' #{Helpers.title_attr(og)} controls loop>
              <source src='#{direct_src}' type='video/mp4'>
            </video>
          HTML
        end

        def image_html(og)
          escaped_url = ::Onebox::Helpers.normalize_url_for_output(og[:url])

          <<-HTML
            <a href='#{escaped_url}' target='_blank' class='onebox'>
              <img src='#{og[:image]}' #{Helpers.title_attr(og)} alt='CloudApp' width='480'>
            </a>
          HTML
        end
    end
  end
end
