module Discourse
  module Oneboxer
    class Preview
      class Example
        TEMPLATE = "blah {{header}} blah"

        def initialize(html)
          @body = html
          @data = extracted_data
          @view = Mustache.render(TEMPLATE, @data)
        end

        def to_html
          @view
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
end
