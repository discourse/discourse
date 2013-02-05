require 'open-uri'
require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class ImgurOnebox < BaseOnebox

    matcher /^https?\:\/\/imgur\.com\/.*$/

    def translate_url
      m = @url.match(/\/gallery\/(?<hash>[^\/]+)/mi)
      return "http://api.imgur.com/2/image/#{URI::encode(m[:hash])}.json" if m.present?

      m = @url.match(/imgur\.com\/(?<hash>[^\/]+)/mi)
      return "http://api.imgur.com/2/image/#{URI::encode(m[:hash])}.json" if m.present?

      nil
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
