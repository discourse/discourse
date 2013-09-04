module Onebox
  module Engine
    class Revision3Onebox
      include Engine
      include OpenGraph

      matches do
        # /^http\:\/\/(.*\.)?revision3\.com\/.*$/
        find "revision3.com"
      end

      private

      def record
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

