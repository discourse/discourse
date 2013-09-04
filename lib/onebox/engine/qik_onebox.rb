module Onebox
  module Engine
    class QikOnebox
      include Engine

      matches do
        # /^https?\:\/\/qik\.com\/video\/.*$/
        find "qik.com"
      end

      private

      def extracted_data
        {
          url: @url,
          title: raw.css(".info h2").inner_text,
          image: raw.css(".userphoto").first["src"]
        }
      end
    end
  end
end
