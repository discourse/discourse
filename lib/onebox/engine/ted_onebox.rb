module Onebox
  module Engine
    class TedOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/(www\.)?ted\.com\/talks\/.*$/
        find "ted.com"
      end

      private

      def record
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description
        }
      end
    end
  end
end

