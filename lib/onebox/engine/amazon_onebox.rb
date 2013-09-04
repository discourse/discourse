module Onebox
  module Engine
    class AmazonOnebox
      include Engine

      matches do
        #/^https?:\/\/(?:www\.)?amazon.(com|ca)\/.*$/
        find "amazon.com"
      end

      private

      def data
        {
          url: @url,
          name: raw.css("html body h1").inner_text,
          image: raw.css("html body #main-image").first["src"],
          description: raw.css("html body #postBodyPS").inner_text,
          price: raw.css("html body .priceLarge").inner_text
        }
      end
    end
  end
end
