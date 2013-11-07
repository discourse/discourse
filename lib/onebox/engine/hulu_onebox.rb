module Onebox
  module Engine
    class HuluOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("hulu")
        tld("com")
        with("/watch/")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.hulu.com",
          badge: "h",
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
          video: raw.metadata[:video][1][:_value]
        }
      end
    end
  end
end

