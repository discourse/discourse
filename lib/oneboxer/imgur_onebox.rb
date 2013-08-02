require 'open-uri'
require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class ImgurOnebox < BaseOnebox

    matcher /^https?\:\/\/imgur\.com\/.*$/

    def translate_url
      hash = image_hash_for(@url) or return nil

      "http://api.imgur.com/2/image/#{URI::encode(hash)}.json"
    end

    def image_hash_for url
      case url
      when /imgur\.com\/user\//mi,
           /imgur\.com\/help(\/|$)/mi
        nil
      when /imgur\.com\/(gallery\/)?(?<hash>[^\/]+)/mi
        $~[:hash]
      else
        nil
      end
    end

    def onebox
      url = translate_url
      return @url if url.blank?

      parsed = JSON.parse(open(translate_url).read)
      image = parsed['image']
      BaseOnebox.image_html(image['links']['original'], image['image']['caption'], image['links']['imgur_page'])
    end

  end
end
