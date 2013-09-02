module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/imgur\.com\/.*$/
        find "imgur.com"
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

