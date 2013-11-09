require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class YoutubeOnebox < OembedOnebox
    matcher /^https?:\/\/(?:www\.)?(?:youtube\.com|youtu\.be)\/.+$/
    def oembed_endpoint
      "http://www.youtube.com/oembed?url=#{BaseOnebox.uriencode(@url.sub('https://', 'http://'))}&format=json"
    end

    def onebox
      super.each do |entry|
        # Youtube allows HTTP and HTTPS, so replace them with the protocol-agnostic variant
        BaseOnebox.replace_agnostic entry
        # Add wmode=opaque to the iframe src URL so that the flash player is rendered within the document flow instead of on top
        BaseOnebox.append_embed_wmode entry
      end
    end
  end
end
