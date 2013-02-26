require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class NfbOnebox < OembedOnebox

    matcher /^https?:\/\/(?:www\.)?nfb\.ca\/film\/[-\w]+\/?/

    def oembed_endpoint
      "http://www.nfb.ca/remote/services/oembed/?url=#{BaseOnebox.uriencode(@url)}&format=json"
    end


  end
end
