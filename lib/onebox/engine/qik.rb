module Onebox
  module Engine
    class Qik
      include Engine

      TEMPLATE = File.read(File.join("templates", "qik.handlebars"))

      def initialize(document, link)
        @url = link
        @body = document
        @data = extracted_data
        @view = Mustache.render(TEMPLATE, @data)
      end

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
