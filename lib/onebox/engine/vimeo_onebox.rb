module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/vimeo\.com\/.*$/
        find "vimeo.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0],
          description: @body.description,
          video: @body.metadata[:video].first[:_value]
        }
      end
    end
  end
end

