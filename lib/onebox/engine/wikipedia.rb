module Onebox
  module Engine
    class Wikipedia
      include Engine

      private

      def extracted_data
        {
          url: @url,
          name: @body.css("html body h1").inner_text,
          image: @body.css(".infobox .image img").first["src"],
          description: @body.css("html body p").inner_text
        }
      end
    end
  end
end
