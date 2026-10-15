# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerOneboxToolbar < PageObjects::Components::Base
      TOOLBAR_SELECTOR = "[data-identifier='composer-onebox-toolbar']"

      def has_toolbar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(TOOLBAR_SELECTOR).filter(visible: true),
        )
      end

      def has_no_toolbar?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(TOOLBAR_SELECTOR).filter(visible: true),
        )
      end

      def has_copy_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("button.composer-onebox-toolbar__copy").filter(visible: true),
        )
      end

      def has_remove_preview_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("button.composer-onebox-toolbar__remove-preview").filter(
            visible: true,
          ),
        )
      end

      def has_visit_link?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("a.composer-onebox-toolbar__visit").filter(visible: true),
        )
      end

      def click_remove_preview
        browser_root
          .locator("button.composer-onebox-toolbar__remove-preview")
          .filter(visible: true)
          .click
        self
      end

      def click_copy
        browser_root.locator("button.composer-onebox-toolbar__copy").filter(visible: true).click
        self
      end
    end
  end
end
