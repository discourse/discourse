module Onebox
  module Engine
    class SoundCloudOnebox
      include Engine
      include LayoutSupport
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
          link: link,
          domain: "http://www.soundcloud.com",
          badge: "s",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end
