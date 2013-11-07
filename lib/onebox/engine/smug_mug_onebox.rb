module Onebox
  module Engine
    class SmugMugOnebox
      include Engine
      include LayoutSupport
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
          link: link,
          domain: "http://www.smugmug.com",
          badge: "i",
          title: raw["author_name"],
          caption: raw["title"],
          image: raw["url"]
        }
      end
    end
  end
end
