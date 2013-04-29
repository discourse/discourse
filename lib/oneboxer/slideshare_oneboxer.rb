require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class SlideshareOnebox < OembedOnebox

    matcher /^https?\:\/\/(www\.)?slideshare\.net\/*\/.*$/

    def oembed_endpoint
      "http://www.slideshare.net/api/oembed/2?url=#{BaseOnebox.uriencode(@url)}&format=json&maxwidth=600"
    end

  end
end

