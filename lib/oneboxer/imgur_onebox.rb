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
      # length check, because imgur has their static pages and
      # prefixes of other lengths
      # new length seems to be pretty final: http://imgur.com/blog/2013/01/18/more-characters-in-filenames/
      # ie. 'help', 'removalrequest', 'user/'
      min_length = 5 # images used to be this long
      max_length = 7 # this is the length for new images
      case url
        $~[:hash]
      when %r<imgur\.com/(gallery/)?(?<hash>[^/]{#{min_length},#{max_length}})>mi
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
