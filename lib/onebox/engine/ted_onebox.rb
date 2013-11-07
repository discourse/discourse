module Onebox
  module Engine
    class TedOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("ted")
        tld("com")
        with("/talks/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.ted.com",
          badge: "t",
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

