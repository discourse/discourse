# frozen_string_literal: true

module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include StandardEmbed

      matches_domain("vimeo.com", "www.vimeo.com")
      requires_iframe_origins "https://player.vimeo.com"
      always_https

      def self.matches_path(path)
        path.match?(%r{^/\d+(/\w+)?/?$})
      end

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
      end

      def to_html
        video_src = Nokogiri::HTML5.fragment(oembed_data[:html]).at_css("iframe")&.[]("src")
        video_src = "https://player.vimeo.com/video/#{oembed_data[:video_id]}" if video_src.blank?
        video_src = video_src.gsub("autoplay=1", "").chomp("?")

        <<-HTML
          <iframe
            class="vimeo-onebox"
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
        @oembed_data = ::MultiJson.load(response, symbolize_keys: true)
      rescue StandardError
        "{}"
      end

      def og_data
        @og_data = get_opengraph
      end
    end
  end
end
