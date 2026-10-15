# frozen_string_literal: true

module PageObjects
  module Components
    class UppyImageUploader < PageObjects::Components::Base
      def initialize(element)
        @element = element
      end

      def select_image(path)
        browser_page
          .expect_file_chooser { @element.locator("label.btn").filter(visible: true).click }
          .set_files(path)
      end

      def select_image_with_keyboard(path)
        label = @element.locator("label.btn").filter(visible: true)
        label.press("Enter")
        browser_page.expect_file_chooser { label.click }.set_files(path)
      end

      def has_uploaded_image?
        # if there's a delete button (.btn-danger), then there must be an
        # uploaded image.
        # allow up to 10 seconds for the upload to finish in case this is
        # called immediately after selecting an image.
        PlaywrightMatchers.have_count(0, timeout: 10 * 1000).does_not_match?(
          @element.locator(".btn-danger").filter(visible: true),
        )
      end

      def remove_image
        @element.locator(".btn-danger").filter(visible: true).click
        PlaywrightMatchers.have_count(0).matches?(
          @element
            .tap do |parent|
              parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
            end
            .locator(".btn-danger")
            .filter(visible: true),
        )
      end

      def remove_image_with_keyboard
        delete_button = @element.locator(".btn-danger").filter(visible: true)
        delete_button.press("Enter")
      end

      def toggle_lightbox_preview
        @element.locator(".image-uploader-lightbox-btn").filter(visible: true).click
      end

      def close_lightbox_preview
        browser_root.locator(".pswp__button--close").filter(visible: true).click
      end

      def has_lightbox_preview?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".pswp--open").filter(visible: true),
        )
      end
    end
  end
end
