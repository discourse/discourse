module Onebox
  module Engine
    class SpotifyOnebox
      include Engine
      include OpenGraph

      matches do
        http
        with("open.")
        domain("spotify")
        tld("com")
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

