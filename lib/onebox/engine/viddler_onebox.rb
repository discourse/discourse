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

      def record
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end

