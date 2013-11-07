module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include LayoutSupport
      include HTML

      matches do
        http
        maybe("www.")
        domain("amazon")
        has(".").either("com", "ca").maybe("/")
      end

      private

      def image
        case
          when raw.css("#main-image").any?
            raw.css("#main-image").first["src"]
          when raw.css("#landingImage").any?
            raw.css("#landingImage").first["src"]
        end
      end

      def data
        {
          link: link,
          domain: "https://amazon.com",
          badge: "a",
          title: raw.css("h1").inner_text,
          image: image,
          description: raw.css("#postBodyPS").inner_text,
          price: raw.css(".priceLarge").inner_text
        }
      end
    end
  end
end
