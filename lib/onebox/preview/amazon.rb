module Onebox
  class Preview
    class Amazon
      TEMPLATE = File.read(File.join("templates", "amazon.handlebars"))

      def initialize(document, link)
        @url = link
        @body = document
        @data = extracted_data
        @view = Mustache.render(TEMPLATE, @data)
      end

      def to_html
        @view
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
