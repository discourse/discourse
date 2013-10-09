require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class YoutubeOnebox < OembedOnebox
    matcher /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/
    def oembed_endpoint
      "http://www.youtube.com/oembed?url=#{BaseOnebox.uriencode(@url.sub('https://', 'http://'))}&format=json"
    end

    def onebox
      # Youtube allows HTTP and HTTPS, so replace them with the protocol-agnostic variant
      super.each { |entry| BaseOnebox.replace_agnostic entry }
    end
  end
end
