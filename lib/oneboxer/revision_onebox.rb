require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class RevisionOnebox < OembedOnebox

    matcher /^http\:\/\/(.*\.)?revision3\.com\/.*$/

    def oembed_endpoint
      "http://revision3.com/api/oembed/?url=#{BaseOnebox.uriencode(@url)}&format=json"
    end

  end
end
