module Onebox
  module Engine
    class WikipediaOnebox
      include Engine

      matches do
        # /^https?:\/\/.*wikipedia\.(com|org)\/.*$/
        find "wikipedia.com"
      end

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
