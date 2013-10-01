module Onebox
  module Engine
    class AmazonOnebox
      include Engine
      include HTML

      matches do
        # matcher /^https?:\/\/itunes.apple.com\/.+$/
        http
        domain("itunes")
        domain("apple")
        tld("com")
      end

      private

      def data
        {
          url: @url,
          title: raw.css("h1").inner_text,
          image: raw.css("#artwork").first["src"],
          description: raw.css("#product-review" "p").first.inner_text,
        }
      end
    end
  end
end
