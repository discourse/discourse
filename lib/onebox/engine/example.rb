module Onebox
  module Engine
    class Example
      include Engine

      TEMPLATE = %|<div class="onebox">{{{header}}}</div>|

      def initialize(document, link)
        @url = link
        @body = document
        @data = extracted_data
        @view = Mustache.render(TEMPLATE, @data)
      end

      private

      def extracted_data
        {
          header: @body.css("html body h1")
        }
      end
    end
  end
end

