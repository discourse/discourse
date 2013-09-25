module Onebox
  module Engine
    class QikOnebox
      include Engine
      include HTML

      matches do
        http
        domain("qik")
        tld("com")
        with("/video")
      end

      private

      def data
        {
          url: @url,
          title: raw.css(".info h2").inner_text,
          image: raw.css(".userphoto").first["src"]
        }
      end
    end
  end
end
