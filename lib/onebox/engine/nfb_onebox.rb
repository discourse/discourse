module Onebox
  module Engine
    class NFBOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("nfb")
        tld("ca")
        with("/film")
      end

      private

      def data
        {
          link: link,
          domain: "http://www.nfb.ca",
          badge: "f",
          title: raw.title,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

