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
          title: @body.title,
          image: @body.images.first,
          description: @body.description
        }
      end
    end
  end
end

