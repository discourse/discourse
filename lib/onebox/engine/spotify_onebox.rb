module Onebox
  module Engine
    class SpotifyOnebox
      include Engine
      include OpenGraph

      matches do
        find "open.spotify.com"
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

