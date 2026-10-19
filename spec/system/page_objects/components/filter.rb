# frozen_string_literal: true

module PageObjects
  module Components
    class Filter < PageObjects::Components::Base
      def filter(text)
        browser_root.locator(".sidebar-filter__input").filter(visible: true).fill(text)
        self
      end

      def clear
        browser_root.locator(".sidebar-filter__clear").filter(visible: true).click
        self
      end
    end
  end
end
