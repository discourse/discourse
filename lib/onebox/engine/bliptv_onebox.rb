module Onebox
  module Engine
    class BliptvOnebox
      include OpenGraph

      def matches
        # /^https?:\/\/blip.tv\/.+$/
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

