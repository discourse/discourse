module Onebox
  module Engine
    class SlideshareOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?\:\/\/(www\.)?slideshare\.net\/*\/.*$/
        find "slideshare.net"
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

