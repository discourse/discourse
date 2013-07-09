require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class SoundcloudOnebox < OembedOnebox
    matcher /^https?:\/\/(?:www\.)?soundcloud\.com\/.+$/
    def oembed_endpoint
      "http://soundcloud.com/oembed?url=#{BaseOnebox.uriencode(@url.sub('https://', 'http://'))}&format=json"
    end
  end
end
