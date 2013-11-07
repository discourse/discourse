 module Onebox
  module Engine
    class ViddlerOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("viddler")
        tld("com")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.viddler.com",
          badge: "v",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

