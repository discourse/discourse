require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class HuluOnebox < OembedOnebox

    matcher /^https?\:\/\/www\.hulu\.com\/watch\/.*$/

    def oembed_endpoint
      "http://www.hulu.com/api/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
    end

  end
end
