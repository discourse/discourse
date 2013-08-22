module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/.*\.flickr\.com\/.*$/
        find "flickr.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images[0],
          description: @body.description
        }
      end
    end
  end
end

