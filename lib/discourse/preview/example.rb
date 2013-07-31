module Discourse
  module Oneboxer
    class Preview
      class Example
        TEMPLATE = "<!DOCTYPE html>\n<html><body><div class='onebox'>{{{header}}}</div></body></html>\n"

        def initialize(document)
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
            header: @body.css("html body h1")
          }
        end
      end
    end
  end
end
