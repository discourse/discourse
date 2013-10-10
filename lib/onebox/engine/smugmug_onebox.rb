module Onebox
  module Engine
    class SmugMugOnebox
      include Engine
      include JSON

      matches do
        http
        words
        domain("smugmug")
        tld("com")
      end

      def url
        "https://api.smugmug.com/services/oembed/?url=#{CGI.escape(@url)}&format=json"
      end

      private

      def data
        {
          url: @url,
          photographer: raw["author_name"],
          caption: raw["title"],
          image: raw["url"]
        }
      end
    end
  end
end
