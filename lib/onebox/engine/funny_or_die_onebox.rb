module Onebox
  module Engine
    class FunnyOrDieOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/(www\.)?funnyordie\.com\/videos\/.*$/$/
        find "funnyordie.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0],
          description: @body.description,
          video: @body.metadata[:video].first[:url].first[:_value]
        }
      end
    end
  end
end

