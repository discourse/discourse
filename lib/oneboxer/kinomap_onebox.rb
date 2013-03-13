require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class KinomapOnebox < OembedOnebox

    matcher /^https?:\/\/(?:www\.)?kinomap\.com/

    def oembed_endpoint
      "http://www.kinomap.com/oembed?url=#{BaseOnebox.uriencode(@url)}&format=json"
    end


  end
end
