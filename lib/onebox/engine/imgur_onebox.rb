module Onebox
  module Engine
    class ImgurOnebox
      include Engine
      include HTML

      matches do
        # /^https?\:\/\/imgur\.com\/.*$/
        find "imgur.com"
      end

      private

      def data
        {
          url: @url
        }
      end
    end
  end
end

