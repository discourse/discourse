# frozen_string_literal: true

require_relative "./opengraph_image"

module Onebox
  module Engine
    class FlickrShortenedOnebox
      include Engine
      include StandardEmbed
      include OpengraphImage

      matches_domain("flic.kr")
      always_https

      def self.matches_path(path)
        path.start_with?("/p/")
      end
    end
  end
end
