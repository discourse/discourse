# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerPreviewToolbar < PageObjects::Components::Base
      TOOLBAR_SELECTOR = "[data-identifier='composer-preview-toolbar']"

      def has_toolbar?
        have_count(0).does_not_match?(browser_root.locator(TOOLBAR_SELECTOR).filter(visible: true))
      end

      def has_no_toolbar?
        have_count(0).matches?(browser_root.locator(TOOLBAR_SELECTOR).filter(visible: true))
      end

      def click_show_source
        browser_root
          .locator("#{TOOLBAR_SELECTOR} button.composer-preview-toolbar__show-source")
          .filter(visible: true)
          .click
        self
      end

      def click_show_preview
        browser_root
          .locator("#{TOOLBAR_SELECTOR} button.composer-preview-toolbar__show-preview")
          .filter(visible: true)
          .click
        self
      end

      def click_control(class_name)
        browser_root.locator("#{TOOLBAR_SELECTOR} button.#{class_name}").filter(visible: true).click
        self
      end

      def has_focused_control?(class_name)
        have_count(0).does_not_match?(
          browser_root.locator("#{TOOLBAR_SELECTOR} button.#{class_name}:focus").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
