require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class SmugmugOnebox < OembedOnebox

    matcher /^https?\:\/\/.*\.smugmug\.com\/.*$/

    def oembed_endpoint
      "http://api.smugmug.com/services/oembed/?url=#{BaseOnebox.uriencode(@url)}&format=json"
    end

  end
end
