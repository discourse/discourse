module Onebox
  module Engine
    class FunnyOrDieOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("funnyordie")
        has(".com").maybe("/videos").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.funnyordie.com",
          badge: "f",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:url].first[:_value]
        }
      end
    end
  end
end

