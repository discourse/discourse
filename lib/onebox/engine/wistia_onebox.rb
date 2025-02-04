# frozen_string_literal: true

module Onebox
  module Engine
    class WistiaOnebox
      include Engine
      include StandardEmbed

      matches_domain("wistia.com", "wi.st", allow_subdomains: true)
      requires_iframe_origins("https://fast.wistia.com", "https://fast.wistia.net")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/(medias|embed)/.*$})
      end

      def to_html
        oembed = get_oembed
        extracted_url = oembed.html.match(/iframe\ src\=\"(.*?)\"/)

        if extracted_url
          iframe_src = extracted_url[1]

          <<~HTML
          <iframe
            src="#{iframe_src}"
            width="#{oembed.width}"
            height="#{oembed.height}"
            title="#{oembed.title}"
            frameborder="0"
            allowfullscreen
          ></iframe>
          HTML
        else
          oembed.html
        end
      end

      def placeholder_html
        oembed = get_oembed
        return if oembed.thumbnail_url.blank?
        "<img src='#{oembed.thumbnail_url}' #{oembed.title_attr}>"
      end

      private

      def get_oembed_url
        "https://fast.wistia.com/oembed?embedType=iframe&url=#{url}"
      end
    end
  end
end
