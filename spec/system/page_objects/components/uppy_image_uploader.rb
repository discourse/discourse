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

      def has_uploaded_picture?
        @element.has_css?(".uploaded-image-preview")
      end
    end
  end
end
