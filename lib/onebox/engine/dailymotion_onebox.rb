module Onebox
  module Engine
    class DailymotionOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?dailymotion\.com\/.+$/
        find "dailymotion.com"
      end

      private

      def record
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.metadata[:video][1][:_value]
        }
      end
    end
  end
end

