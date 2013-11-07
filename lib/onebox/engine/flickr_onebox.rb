module Onebox
  module Engine
    class FlickrOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        domain("flickr")
        has(".com").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.flickr.com",
          badge: "f",
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

