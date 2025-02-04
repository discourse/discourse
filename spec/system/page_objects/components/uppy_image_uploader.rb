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

      def select_image_with_keyboard(path)
        label = @element.find("label.btn-default")
        label.send_keys(:enter)
        attach_file(path) { label.click }
      end

      def has_uploaded_image?
        # if there's a delete button (.btn-danger), then there must be an
        # uploaded image.
        # allow up to 10 seconds for the upload to finish in case this is
        # called immediately after selecting an image.
        @element.has_css?(".btn-danger", wait: 10)
      end

      def remove_image
        @element.find(".btn-danger").click
      end

      def remove_image_with_keyboard
        delete_button = @element.find(".btn-danger")
        delete_button.send_keys(:enter)
      end
    end
  end
end
