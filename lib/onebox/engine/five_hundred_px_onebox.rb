# frozen_string_literal: true

module Onebox
  module Engine
    class FiveHundredPxOnebox
      include Engine
      include StandardEmbed

      matches_domain("500px.com")
      always_https

      def self.matches_path(path)
        path.match?(%r{^/photo/\d+/})
      end

      def to_html
        og = get_opengraph
        "<img src='#{og.image}' width='#{og.image_width}' height='#{og.image_height}' class='onebox' #{og.title_attr}>"
      end
    end
  end
end
