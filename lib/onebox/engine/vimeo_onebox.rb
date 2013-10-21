module Onebox
  module Engine
    class VimeoOnebox
      include Engine
      include OpenGraph

      matches do
        http
        domain("vimeo")
        tld("com")
      end

      private

      def data
        {
          link: link,
          domain: "http://vimeo.com",
          badge: "v",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

