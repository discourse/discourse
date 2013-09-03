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

      def extracted_data
        {
          url: @url
        }
      end
    end
  end
end

