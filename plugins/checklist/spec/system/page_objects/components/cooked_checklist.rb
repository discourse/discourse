# frozen_string_literal: true

module PageObjects
  module Components
    class CookedChecklist < PageObjects::Components::Base
      CHECKBOX_SELECTOR = ".cooked .chcklst-box"

      def click_checkbox
        find(CHECKBOX_SELECTOR).click
        self
      end

      def has_saved_checked?
        has_css?("#{CHECKBOX_SELECTOR}.checked:not([aria-busy])")
      end
    end
  end
end
