module Onebox
  module Engine
    class ExampleOnebox
      include Engine
      include HTML

      matches do
        find "example.com"
      end

      private

      def data
        {
          header: raw.css("h1").inner_text
        }
      end

      def template
        %|<div class="onebox">{{header}}</div>|
      end
    end
  end
end

