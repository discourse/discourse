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

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.video
        }
      end
    end
  end
end
