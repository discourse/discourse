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

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end
