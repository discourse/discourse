module Onebox
  module Engine
    class NFBOnebox
      include Engine
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
          url: @url,
          title: raw.title,
          description: raw.description,
          video: raw.metadata[:video].first[:_value]
        }
      end
    end
  end
end

