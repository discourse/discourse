module Onebox
  module Engine
    class ItunesOnebox
      include Engine
      include OpenGraph

      matches do
        # matcher /^https?:\/\/itunes.apple.com\/.+$/
        http
        domain("itunes")
        has(".")
        domain("apple")
        tld("com")
      end

      private

      def data
        {
          url: @url,
          title: raw.title,
          image: raw.images.first,
          description: raw.description,
        }
      end
    end
  end
end
