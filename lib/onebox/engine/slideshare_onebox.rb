module Onebox
  module Engine
    class SlideshareOnebox
      include Engine
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("slideshare")
        tld("net")
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

