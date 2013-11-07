module Onebox
  module Engine
    class ClikThroughOnebox
      include Engine
      include LayoutSupport
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("clikthrough")
        has(".com").either("/theater", "/video").maybe("/")
      end

      private

      def data
        {
          link: link,
          domain: "http://clikthrough.com",
          badge: "c",
          title: raw.title,
          description: raw.description
        }
      end
    end
  end
end
