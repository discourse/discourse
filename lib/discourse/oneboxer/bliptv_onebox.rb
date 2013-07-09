require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class BliptvOnebox < OembedOnebox

    matcher /^https?\:\/\/blip\.tv\/.+$/

    def oembed_endpoint
      "http://blip.tv/oembed/?url=#{BaseOnebox.uriencode(@url)}&width=300"
    end

  end
end
