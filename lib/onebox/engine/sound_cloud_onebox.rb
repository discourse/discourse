module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include OpenGraph

      matches do
        # /^https?:\/\/(?:www\.)?soundcloud\.com\/.+$/
        find "soundcloud.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: @body.title,
          image: @body.images.first,
          description: @body.description,
          video: @body.metadata[:video][1][:_value]
        }
      end
    end
  end
end
