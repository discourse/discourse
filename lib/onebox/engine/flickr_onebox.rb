# frozen_string_literal: true

require_relative './opengraph_image'

module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include StandardEmbed
      include OpengraphImage

      matches_regexp(/^https?:\/\/www\.flickr\.com\/photos\//)
      always_https
    end
  end
end
