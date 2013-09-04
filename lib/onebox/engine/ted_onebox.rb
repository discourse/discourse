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
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

