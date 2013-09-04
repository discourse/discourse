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
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

