module Onebox
  module Engine
    class Example
      include Engine

      TEMPLATE = %|<div class="onebox">{{{header}}}</div>|

      def initialize(link)
        @url = link
        @body = read
        @data = extracted_data
        @view = Mustache.render(TEMPLATE, @data)
      end

      private

      def extracted_data
        {
          header: @body.css("html body h1")
        }
      end

      def read
        Nokogiri::HTML(open(@url))
      end
    end
  end
end

