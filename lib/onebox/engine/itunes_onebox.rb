module Onebox
  module Engine
    class ItunesOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        # matcher /^https?:\/\/itunes.apple.com\/.+$/
        http
        domain("itunes")
        has(".")
        domain("apple")
        tld("com")
      end

      private

      def data
        {
          link: link,
          domain: "http://itunes.apple.com",
          badge: "i",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
        }
      end
    end
  end
end
