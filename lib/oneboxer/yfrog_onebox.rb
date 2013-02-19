require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class YfrogOnebox < OembedOnebox

    matcher /^https?:\/\/(?:www\.)?yfrog\.(com|ru|com\.tr|it|fr|co\.il|co\.uk|com\.pl|pl|eu|us)\/[a-zA-Z0-9]+/

    def oembed_endpoint
      "http://www.yfrog.com/api/oembed/?url=#{BaseOnebox.uriencode(@url)}&format=json"
    end

  end
end
