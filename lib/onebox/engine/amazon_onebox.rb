module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include HTML

      matches do
        http
        maybe("www.")
        domain("amazon")
        has(".").either("com", "ca").maybe("/")
      end

      private

      def data
        {
          url: @url,
          name: raw.css("h1").inner_text,
          image: raw.css("#main-image").first["src"],
          description: raw.css("#postBodyPS").inner_text,
          price: raw.css(".priceLarge").inner_text
        }
      end
    end
  end
end
