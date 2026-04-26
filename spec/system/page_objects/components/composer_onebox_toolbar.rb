# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerOneboxToolbar < PageObjects::Components::Base
      TOOLBAR_SELECTOR = "[data-identifier='composer-onebox-toolbar']"

      def has_toolbar?
        page.has_css?(TOOLBAR_SELECTOR)
      end

      def has_no_toolbar?
        page.has_no_css?(TOOLBAR_SELECTOR)
      end

      def has_copy_button?
        page.has_css?("button.composer-onebox-toolbar__copy")
      end

      def has_remove_preview_button?
        page.has_css?("button.composer-onebox-toolbar__remove-preview")
      end

      def has_visit_link?
        page.has_css?("a.composer-onebox-toolbar__visit")
      end

      def click_remove_preview
        page.find("button.composer-onebox-toolbar__remove-preview").click
        self
      end

      def click_copy
        page.find("button.composer-onebox-toolbar__copy").click
        self
      end
    end
  end
end
