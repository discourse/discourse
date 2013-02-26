require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class ClikthroughOnebox < OembedOnebox

    matcher /^https?:\/\/(?:www\.)?clikthrough\.com\/theater\/video\/\d+$/

    def oembed_endpoint
      "http://clikthrough.com/services/oembed?url=#{BaseOnebox.uriencode(@url)}"
    end


  end
end
