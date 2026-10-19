# frozen_string_literal: true

module PageObjects
  module Modals
    class CreateColorPalette < PageObjects::Pages::Base
      def modal
        browser_root.locator(".create-color-palette").filter(visible: true)
      end

      def base_dropdown
        PageObjects::Components::SelectKit.new(".select-base-palette")
      end

      def create_button
        within_browser(modal) { browser_root.locator(".btn-primary").filter(visible: true) }
      end
    end
  end
end
