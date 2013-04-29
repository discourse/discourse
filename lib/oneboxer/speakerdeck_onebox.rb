require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class SpeakerdeckOnebox < OembedOnebox

    matcher /^https?\:\/\/(www\.)?speakerdeck\.com\/*\/.*$/

    def oembed_endpoint
      "http://speakerdeck.com/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
    end

  end
end
