# frozen_string_literal: true

module Onebox
  module Engine
    class CoubOnebox
      include Engine
      include StandardEmbed

      matches_domain("coub.com")
      always_https

      def self.matches_path(path)
        path.start_with?("/view/")
      end

      def placeholder_html
        oembed = get_oembed
        "<img src='#{oembed.thumbnail_url}' height='#{oembed.thumbnail_height}' width='#{oembed.thumbnail_width}' #{oembed.title_attr}>"
      end

      def to_html
        get_oembed.html
      end
    end
  end
end
