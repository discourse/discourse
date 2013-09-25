module Onebox
  module Engine
    class DotsubOnebox
      include Engine
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
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end
