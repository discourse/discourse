# frozen_string_literal: true

module PageObjects
  module Components
    class UppyImageUploader < PageObjects::Components::Base
      def initialize(element)
        @element = element
      end

      def select_image(path)
        attach_file(path) { @element.find("label.btn-default").click }
      end

      def has_uploaded_image?
        # if there's a delete button (.btn-danger), then there must be an
        # uploaded image.
        # allow up to 10 seconds for the upload to finish in case this is
        # called immediately after selecting an image.
        @element.has_css?(".btn-danger", wait: 10)
      end
    end
  end
end
