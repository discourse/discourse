module Onebox
  module Engine
    class StackExchange
      include Engine

      TEMPLATE = File.read(File.join("templates", "stackexchange.handlebars"))

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
          title: @body.css(".question-hyperlink").inner_text,
          question: @body.css(".question .post-text p").first.inner_text
        }
      end
    end
  end
end
