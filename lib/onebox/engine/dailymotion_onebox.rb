module Onebox
  module Engine
    class DailymotionOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("dailymotion")
        has(".com").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.dailymotion.com",
          badge: "d",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

