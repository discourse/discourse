module Onebox
  module Engine
    class BliptvOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/blip.tv\/.+$/
        find "blip.tv"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0],
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end

