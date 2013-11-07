module Onebox
  module Engine
    class SlideshareOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("slideshare")
        tld("net")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.slideshare.net",
          badge: "s",
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

