module Onebox
  module Engine
    class FunnyOrDieOnebox
      include Engine
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
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:url].first[:_value]
        }
      end
    end
  end
end

