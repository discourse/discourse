module Onebox
  module Engine
    class QikOnebox
      include Engine

      private

      def extracted_data
        {
          url: @url,
          title: @body.css(".info h2").inner_text,
          image: @body.css(".userphoto").first["src"]
        }
      end
    end
  end
end
