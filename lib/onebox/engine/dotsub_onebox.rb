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
          url: @body.metadata[:url].first[:_value],
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end
