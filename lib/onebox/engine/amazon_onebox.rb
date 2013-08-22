module Onebox
  module Engine
    class AmazonOnebox
      include Engine

      matches do
        #/^https?:\/\/(?:www\.)?amazon.(com|ca)\/.*$/
        find "amazon.com"
      end

      private

      def extracted_data
        {
          url: @url,
          name: @body.css("html body h1").inner_text,
          image: @body.css("html body #main-image").first["src"],
          description: @body.css("html body #postBodyPS").inner_text,
          price: @body.css("html body .priceLarge").inner_text
        }
      end
    end
  end
end
