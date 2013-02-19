require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class DotsubOnebox < OembedOnebox

    matcher /^https?:\/\/(?:www\.)?dotsub\.com\/.+$/

    def oembed_endpoint
      "http://dotsub.com/services/oembed?url=#{BaseOnebox.uriencode(@url)}"
    end


  end
end
