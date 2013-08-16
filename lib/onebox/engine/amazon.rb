module Onebox
  module Engine
    class Amazon
      include Engine

      TEMPLATE = File.read(File.join("templates", "amazon.handlebars"))

      def initialize(link)
        @url = link
        @body = read
        @data = extracted_data
        @view = Mustache.render(TEMPLATE, @data)
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

      def read
        Nokogiri::HTML(open(@url))
      end
    end
  end
end
