module Onebox
  module Engine
    class TedOnebox
      include Engine
      include OpenGraph

      matches do
        http
        maybe("www.")
        domain("ted")
        tld("com")
        with("/talks/")
      end

      private

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description
        }
      end
    end
  end
end

