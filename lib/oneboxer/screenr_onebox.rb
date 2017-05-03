require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class ScreenrOnebox < OembedOnebox

    matcher /^https?\:\/\/(www\.)?screenr\.com\/.*$/

    def oembed_endpoint
      # maxwidth and width does not work with Screenr's Oembed, but they could add it with time
      "http://www.screenr.com/api/oembed.json?url=#{BaseOnebox.uriencode(@url)}&width=600&maxwidth=700"
    end

  end
end
