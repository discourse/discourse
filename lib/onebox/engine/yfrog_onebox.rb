module Onebox
  module Engine
    class YfrogOnebox
      include Engine
      include OpenGraph

      matches do
        http
        maybe("www.")
        maybe("twitter.")
        domain("yfrog")
        either(".com", ".ru", ".tr", ".it", ".fr", ".co", ".uk", ".pl", ".eu", ".us")
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

