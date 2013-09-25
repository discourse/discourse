module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include OpenGraph

      matches do
        http
        domain("flickr")
        has(".com").maybe("/")
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

