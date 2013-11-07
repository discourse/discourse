module Onebox
  module Engine
    class YfrogOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        maybe("twitter.")
        domain("yfrog")
        either(".com", ".ru", ".tr", ".it", ".fr", ".co", ".uk", ".pl", ".eu", ".us")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.yfrog.com",
          badge: "y",
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

