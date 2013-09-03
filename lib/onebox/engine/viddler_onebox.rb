module Onebox
  module Engine
    class ViddlerOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?viddler\.com\/.+$/
        find "viddler.com"
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

