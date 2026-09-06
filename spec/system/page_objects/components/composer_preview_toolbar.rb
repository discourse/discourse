# frozen_string_literal: true

module PageObjects
  module Components
    class ComposerPreviewToolbar < PageObjects::Components::Base
      TOOLBAR_SELECTOR = "[data-identifier='composer-preview-toolbar']"

      def has_toolbar?
        page.has_css?(TOOLBAR_SELECTOR)
      end

      def has_no_toolbar?
        page.has_no_css?(TOOLBAR_SELECTOR)
      end

      def click_show_source
        page.find("#{TOOLBAR_SELECTOR} button.composer-preview-toolbar__show-source").click
        self
      end

      def click_show_preview
        page.find("#{TOOLBAR_SELECTOR} button.composer-preview-toolbar__show-preview").click
        self
      end

      def click_control(class_name)
        page.find("#{TOOLBAR_SELECTOR} button.#{class_name}").click
        self
      end

      def has_focused_control?(class_name)
        page.has_css?("#{TOOLBAR_SELECTOR} button.#{class_name}:focus")
      end
    end
  end
end
