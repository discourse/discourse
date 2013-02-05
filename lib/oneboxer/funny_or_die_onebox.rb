require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class FunnyOrDieOnebox < OembedOnebox
    matcher /^https?\:\/\/(www\.)?funnyordie\.com\/videos\/.*$/
    def oembed_endpoint
      "http://www.funnyordie.com/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
    end
  end
end
