module Onebox
  module Engine
    class DotsubOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("dotsub")
        has(".com").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.dotsub.com",
          badge: "d",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end
