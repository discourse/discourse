module Discourse
  module Oneboxer
    class ImgurOnebox < BaseOnebox

      matcher /^https?\:\/\/imgur\.com\/.*$/

      def translate_url
        match = @url.match(%r<imgur\.com/(gallery/)?(?<hash>[^/]+)>mi)

        return nil unless valid_hash(match[:hash])

        "http://api.imgur.com/2/image/#{URI::encode(match[:hash])}.json"
      end

      def valid_hash hash
        # http://imgur.com/blog/2013/01/18/more-characters-in-filenames/
        # maximum length of 7 seems pretty final
        # this check ensures we don't match non-image pages like 'help', 'removalrequest', 'user/'
        hash and hash.length.between?(5,7)
      end

      def onebox
        url = translate_url
        return @url if url.blank?

        parsed = JSON.parse(open(translate_url).read)
        image = parsed['image']['links']['original']
        url   = parsed['image']['image']['caption']
        title = parsed['image']['links']['imgur_page']

        BaseOnebox.image_html(image, url, title)
      end


    end
  end
end
