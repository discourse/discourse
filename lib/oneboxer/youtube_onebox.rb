require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class YoutubeOnebox < OembedOnebox
    matcher /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/
    def oembed_endpoint
      "http://www.youtube.com/oembed?url=#{BaseOnebox.uriencode(@url.sub('https://', 'http://'))}&format=json"
    end
  end
end
