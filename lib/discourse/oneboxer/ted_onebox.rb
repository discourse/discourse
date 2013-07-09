require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class TedOnebox < OembedOnebox
    matcher /^https?\:\/\/(www\.)?ted\.com\/talks\/.*$/
    def oembed_endpoint
      "http://www.ted.com/talks/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
    end
  end
end
