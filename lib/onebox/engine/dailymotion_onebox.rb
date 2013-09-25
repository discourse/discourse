module Onebox
  module Engine
    class DailymotionOnebox
      include Engine
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
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

