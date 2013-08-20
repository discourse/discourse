module Onebox
  module Engine
    class FlickrOnebox
      include OpenGraph

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0]
        }
      end
    end
  end
end

