module Onebox
  module Engine
    class ClikThroughOnebox
      include Engine
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
          url: @url,
          title: raw.title,
          description: raw.description
        }
      end
    end
  end
end
