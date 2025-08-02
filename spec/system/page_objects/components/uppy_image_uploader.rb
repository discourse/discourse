# frozen_string_literal: true

module PageObjects
  module Components
    class UppyImageUploader < PageObjects::Components::Base
      def initialize(element)
        @element = element
      end

      def select_image(path)
        attach_file(path) { @element.find("label.btn").click }
      end

      def select_image_with_keyboard(path)
        label = @element.find("label.btn")
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
        @element.has_no_css?(".btn-danger")
      end

      def remove_image_with_keyboard
        delete_button = @element.find(".btn-danger")
        delete_button.send_keys(:enter)
      end

      def toggle_lightbox_preview
        @element.find(".image-uploader-lightbox-btn").click
      end

      def has_lighbox_preview?
        has_css?(".mfp-container")
      end
    end
  end
end
