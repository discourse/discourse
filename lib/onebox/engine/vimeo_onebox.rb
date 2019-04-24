module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?vimeo\.com\/\d+(\/[^\/]+)?$/)
      always_https

      WIDTH  ||= 640
      HEIGHT ||= 360

      def placeholder_html
        image_src = og_data.image_secure_url || og_data.image_url
        "<img src='#{image_src}' width='#{WIDTH}' height='#{HEIGHT}' #{og_data.title_attr}>"
      end

      def to_html
        video_src = og_data.video_secure_url || og_data.video_url
        video_src = video_src.gsub('autoplay=1', '').chomp("?")
        <<-HTML
          <iframe width="#{WIDTH}"
                  height="#{HEIGHT}"
                  src="#{video_src}"
                  data-original-href="#{link}"
                  frameborder="0"
                  allowfullscreen>
          </iframe>
        HTML
      end

      private

      def og_data
        @og_data = get_opengraph
      end
    end
  end
end
