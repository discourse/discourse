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

      def data
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

