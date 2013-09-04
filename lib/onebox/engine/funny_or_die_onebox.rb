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

      def record
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

