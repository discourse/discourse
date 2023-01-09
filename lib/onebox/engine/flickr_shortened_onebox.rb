# frozen_string_literal: true

require_relative "./opengraph_image"

module Onebox
  module Engine
    class FlickrShortenedOnebox
      include Engine
      include StandardEmbed
      include OpengraphImage

      matches_regexp(%r{^https?://flic\.kr/p/})
      always_https
    end
  end
end
