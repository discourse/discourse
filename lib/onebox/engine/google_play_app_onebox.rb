module Onebox
  module Engine
    class GooglePlayAppOnebox
      include Engine
      include HTML

      matches do
        http
        with("play.")
        domain("google")
        tld("com")
        with("/store/apps/")
      end

      private

      def data
      binding.pry
        {
          url: @url,
          # name: raw.css("h1").inner_text,
          # image: raw.css("#main-image").first["src"],
          # description: raw.css("#postBodyPS").inner_text,
          # price: raw.css(".priceLarge").inner_text
        }
      end
    end
  end
end
