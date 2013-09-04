module Onebox
  module Engine
    class DotsubOnebox
      include Engine
      include OpenGraph

      matches do
        # matcher /^https?:\/\/(?:www\.)?dotsub\.com\/.+$/
        find "dotsub.com"
      end

      private

      def record
        {
          url: raw.metadata[:url].first[:_value],
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end
