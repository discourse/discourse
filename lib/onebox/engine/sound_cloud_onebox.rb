module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("soundcloud")
        tld("com")
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
