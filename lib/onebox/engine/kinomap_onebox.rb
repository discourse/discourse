module Onebox
  module Engine
    class KinomapOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        domain("kinomap")
        tld("com")
        with("/watch/")
      end

      private

      def data
        {
          link: link,
          domain: "http://kinomap.com",
          badge: "k",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end
