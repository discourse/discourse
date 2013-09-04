module Onebox
  module Engine
    class ExampleOnebox
      include Engine

      matches do
        find "example.com"
      end

      private

      def record
        {
          header: raw.css("html body h1")
        }
      end

      def template
        %|<div class="onebox">{{{header}}}</div>|
      end
    end
  end
end

