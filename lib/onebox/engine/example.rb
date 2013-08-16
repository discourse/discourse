module Onebox
  module Engine
    class Example
      include Engine

      private

      def extracted_data
        {
          header: @body.css("html body h1")
        }
      end

      def template
        %|<div class="onebox">{{{header}}}</div>|
      end
    end
  end
end

