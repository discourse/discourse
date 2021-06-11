# frozen_string_literal: true

module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(www\.)?vimeo\.com\/\d+/)
      requires_iframe_origins "https://player.vimeo.com"
      always_https

      WIDTH  ||= 640
      HEIGHT ||= 360

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
      end

      def to_html
        video_id = oembed_data[:video_id]
        if video_id.nil?
          # for private videos
          video_id = uri.path[/\/(\d+)/, 1]
        end
        video_src = "https://player.vimeo.com/video/#{video_id}"
        video_src = video_src.gsub('autoplay=1', '').chomp("?")

        <<-HTML
          <iframe
            width="#{WIDTH}"
            height="#{HEIGHT}"
            src="#{video_src}"
            data-original-href="#{link}"
            frameborder="0"
            allowfullscreen
          ></iframe>
        HTML
      end

      private

      def oembed_data
        response = Onebox::Helpers.fetch_response("https://vimeo.com/api/oembed.json?url=#{url}")
        @oembed_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
      rescue
        "{}"
      end

      def og_data
        @og_data = get_opengraph
      end
    end
  end
end
