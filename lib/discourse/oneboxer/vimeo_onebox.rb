require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class VimeoOnebox < OembedOnebox

    matcher /^https?\:\/\/vimeo\.com\/.*$/

    def oembed_endpoint
      "http://vimeo.com/api/oembed.json?url=#{BaseOnebox.uriencode(@url)}&width=600"
    end

  end
end
